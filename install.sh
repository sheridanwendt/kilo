#!/usr/bin/env bash
# hermes-personal-assistant — single-command installer.
#
#   git clone https://github.com/sheridanwendt/kilo.git
#   cd hermes-personal-assistant
#   ./install.sh --profile on-prem
#
# Installs Ollama (default, offline, free), installs upstream Hermes Agent,
# applies a config profile, and registers boot-time systemd services.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR/overlay"
INSTALL_DIR="$OVERLAY_DIR/install"

PROFILE="on-prem"
UPDATE_ONLY=false
SKIP_AUTOSTART=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--profile <on-prem|cloud-server|usb-offline>] [--update] [--skip-autostart]

  --profile <name>   Config profile to apply (default: on-prem)
  --update           Skip OS-level setup, just re-apply profile + pull upstream updates
  --skip-autostart   Don't register systemd boot services (useful for USB image builds
                      where autostart is configured differently, or for manual testing)
  -h, --help         Show this help
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
  echo "==> Update complete."
  exit 0
fi

echo "==> Step 1/4: Installing Ollama (default local model provider)"
bash "$INSTALL_DIR/01-install-ollama.sh"

echo "==> Step 2/4: Installing Hermes Agent (upstream)"
bash "$INSTALL_DIR/02-install-hermes.sh"

echo "==> Step 3/4: Applying profile '$PROFILE'"
bash "$INSTALL_DIR/03-apply-profile.sh"

if [[ "$SKIP_AUTOSTART" == false ]]; then
  echo "==> Step 4/4: Registering boot-time autostart"
  bash "$INSTALL_DIR/04-enable-autostart.sh"
else
  echo "==> Step 4/4: Skipped (--skip-autostart)"
fi

echo "==> Done. Run 'hermes' to chat, or check 'systemctl status hermes-gateway ollama' for the running services."
