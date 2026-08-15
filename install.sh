#!/usr/bin/env bash
# hermes-personal-assistant - single-command installer.
#
#   git clone https://github.com/sheridanwendt/kilo.git
#   cd kilo
#   ./install.sh --profile on-prem
#
# If ./kilo already exists from a previous attempt, `git clone` above will
# fail (harmlessly) and `cd kilo` will drop you into whatever old code is
# already there. To always get the current version:
#
#   git clone https://github.com/sheridanwendt/kilo.git kilo 2>/dev/null || (cd kilo && git pull origin main)
#   cd kilo && ./install.sh --profile on-prem
#
# Installs baseline OS prerequisites, Ollama (default, offline, free),
# installs upstream Hermes Agent, applies a config profile, and registers
# boot-time systemd services. Designed to work on a genuinely fresh Ubuntu
# install with zero pre-installed dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR/overlay"
INSTALL_DIR="$OVERLAY_DIR/install"

# shellcheck source=overlay/install/lib-apt-ipv4-fallback.sh
source "$INSTALL_DIR/lib-apt-ipv4-fallback.sh"

PROFILE="on-prem"
UPDATE_ONLY=false
SKIP_AUTOSTART=false
SKIP_UPDATE_CHECK="${HPA_SKIP_UPDATE_CHECK:-0}"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--profile <on-prem|cloud-server|usb-offline>] [--update] [--skip-autostart]

  --profile <name>   Config profile to apply (default: on-prem)
  --update           Skip OS-level setup, just re-apply profile + pull upstream updates
  --skip-autostart   Don't register systemd boot services (useful for USB image builds
                      where autostart is configured differently, or for manual testing)
  -h, --help         Show this help

Env vars:
  HPA_SKIP_UPDATE_CHECK=1   Skip the "is this checkout stale" check below (e.g. for an
                            intentionally offline USB build with no network access)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --update) UPDATE_ONLY=true; shift ;;
    --skip-autostart) SKIP_AUTOSTART=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- Guard 1: make sure the bare minimum tools this very script needs exist. ---
# Belt-and-suspenders alongside overlay/install/00-install-prereqs.sh (which
# installs the full prereq list as its own numbered step): this inline
# check guarantees curl and git specifically are present before we even
# get to the update-staleness check below, which needs git to work.
ensure_core_tools() {
  local missing=()
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  command -v git  >/dev/null 2>&1 || missing+=(git)
  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi
  echo "==> Bootstrapping missing core tools before anything else: ${missing[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    echo "  - Running apt-get update (output below; can take a moment on a fresh machine)"
    hpa_apt_update_with_ipv4_fallback
    echo "  - Installing: ${missing[*]} ca-certificates"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" ca-certificates
  else
    echo "  ! No apt-get available and missing: ${missing[*]}. Install these manually," >&2
    echo "    then re-run ./install.sh." >&2
    exit 1
  fi
}
ensure_core_tools

# --- Guard 2: catch a stale checkout before it causes a confusing error further in. ---
# This is exactly the failure mode that prompted this guard: git clone
# silently no-ops against a non-empty directory left over from a previous
# attempt, so an old install.sh (missing later fixes) runs instead and
# fails deep inside a sub-script with something like "curl: command not
# found" - which is confusing to debug because the real problem is that
# old code is running, not the error you actually see.
check_for_stale_checkout() {
  if [[ "$SKIP_UPDATE_CHECK" == "1" ]]; then
    return 0
  fi
  if ! git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi

  local local_head remote_head
  local_head="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)"

  if ! git -C "$SCRIPT_DIR" fetch --quiet origin main 2>/dev/null; then
    # Fails silently (by design) if offline, or if this is a private repo
    # and no git credentials are cached on this machine (SSH key, `gh auth
    # login`, or a credential helper) -- an anonymous fetch against a
    # private repo errors out rather than just timing out, and we treat
    # that the same as "can't check" rather than blocking the install.
    echo "  (couldn't fetch origin/main - offline, or no git credentials" \
         "cached for a private repo - skipping stale-checkout check)"
    return 0
  fi
  remote_head="$(git -C "$SCRIPT_DIR" rev-parse origin/main 2>/dev/null || true)"

  if [[ -n "$local_head" && -n "$remote_head" && "$local_head" != "$remote_head" ]] \
     && git -C "$SCRIPT_DIR" merge-base --is-ancestor "$local_head" "$remote_head" 2>/dev/null; then
    echo "==============================================================" >&2
    echo " This checkout is behind origin/main - stop before it fails" >&2
    echo " confusingly a few steps in." >&2
    echo "" >&2
    echo "   local:  ${local_head}" >&2
    echo "   origin: ${remote_head}" >&2
    echo "" >&2
    echo " Fix:" >&2
    echo "   git -C \"$SCRIPT_DIR\" pull origin main" >&2
    echo "   $SCRIPT_DIR/install.sh --profile $PROFILE" >&2
    echo "" >&2
    echo " This is the exact stale-directory-from-a-previous-attempt" >&2
    echo " scenario: git clone silently no-ops against a non-empty" >&2
    echo " directory, leaving old code in place." >&2
    echo "" >&2
    echo " To proceed anyway (e.g. intentionally offline USB build):" >&2
    echo "   HPA_SKIP_UPDATE_CHECK=1 $SCRIPT_DIR/install.sh --profile $PROFILE" >&2
    echo "==============================================================" >&2
    exit 1
  fi
}
check_for_stale_checkout

PROFILE_FILE="$OVERLAY_DIR/config-profiles/${PROFILE}.yaml"
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Unknown profile '$PROFILE'. Available profiles:" >&2
  ls "$OVERLAY_DIR/config-profiles" | sed 's/\.yaml$//' >&2
  exit 1
fi

echo "==> hermes-personal-assistant install (profile: $PROFILE, update-only: $UPDATE_ONLY)"

export HPA_PROFILE="$PROFILE"
export HPA_PROFILE_FILE="$PROFILE_FILE"
export HPA_OVERLAY_DIR="$OVERLAY_DIR"

if [[ "$UPDATE_ONLY" == true ]]; then
  echo "==> Update mode: re-applying profile + pulling upstream Hermes updates"
  bash "$INSTALL_DIR/02-install-hermes.sh" --update
  bash "$INSTALL_DIR/03-apply-profile.sh"
  "$SCRIPT_DIR/sync-to-hermes.sh" --hermes-dir "$HOME/.hermes" --yes
  echo "==> Update complete."
  exit 0
fi

echo "==> Step 1/6: Installing baseline OS prerequisites"
bash "$INSTALL_DIR/00-install-prereqs.sh"

echo "==> Step 2/6: Installing Ollama (default local model provider)"
bash "$INSTALL_DIR/01-install-ollama.sh"

echo "==> Step 3/6: Installing Hermes Agent (upstream)"
bash "$INSTALL_DIR/02-install-hermes.sh"

echo "==> Step 4/6: Applying profile '$PROFILE'"
bash "$INSTALL_DIR/03-apply-profile.sh"

if [[ "$SKIP_AUTOSTART" == false ]]; then
  echo "==> Step 5/6: Registering boot-time autostart"
  bash "$INSTALL_DIR/04-enable-autostart.sh"
else
  echo "==> Step 5/6: Skipped (--skip-autostart)"
fi

echo "==> Step 6/6: Syncing custom skills (and memories/cron/hooks, once populated)"
"$SCRIPT_DIR/sync-to-hermes.sh" --hermes-dir "$HOME/.hermes" --yes

echo "==> Done. Run 'hermes' to chat, or check 'systemctl status hermes-gateway ollama' for the running services."
