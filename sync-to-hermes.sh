#!/usr/bin/env bash
# Syncs this repo's authored Hermes content (skills/, and memories/, cron/,
# hooks/ once populated) onto an *existing* Hermes agent installation.
#
# For someone who already has a working Hermes agent and just wants this
# repo's content applied or refreshed, without a full ./install.sh run
# (no OS packages, no Ollama, no systemd, no config.yaml changes):
#
#   git clone https://github.com/sheridanwendt/kilo.git
#   cd kilo
#   ./sync-to-hermes.sh
#
# Linux/macOS/WSL2 only. Windows-native equivalent: sync-to-hermes.ps1
# (PowerShell) - same content, same behavior, native tooling per OS
# rather than requiring WSL/Git Bash on a Windows box just to run this.
#
# Idempotent and safe to re-run: each synced item is fully replaced from
# this repo's copy every time.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR/overlay"
CATEGORIES=(skills memories cron hooks)

# HPA_HERMES_DIR lets you point this at a non-default install (or a
# --hermes-dir flag below); otherwise assume the standard Linux/macOS
# location. See docs/open-questions.md #11 - this, and the memories/cron/
# hooks locations below it, are best-effort assumptions about Hermes's
# directory layout, not confirmed against every possible Hermes version.
HERMES_DIR="${HPA_HERMES_DIR:-$HOME/.hermes}"
ASSUME_YES=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./sync-to-hermes.sh [--hermes-dir <path>] [--yes] [--dry-run]

Copies overlay/{skills,memories,cron,hooks} from this repo onto an
existing Hermes agent's directory. Does not touch config.yaml, Ollama, or
systemd - use ./install.sh for a full/first-time setup instead.

  --hermes-dir <path>   Override the detected Hermes agent directory
                         (default: $HPA_HERMES_DIR, else ~/.hermes)
  --yes, -y             Skip the confirmation prompt
  --dry-run             Show what would be copied without copying anything
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hermes-dir) HERMES_DIR="$2"; shift 2 ;;
    --yes|-y) ASSUME_YES=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -d "$HERMES_DIR" ]]; then
  echo "No Hermes agent directory found at: $HERMES_DIR" >&2
  echo "  - If Hermes is installed somewhere else, pass --hermes-dir <path>" >&2
  echo "    or set HPA_HERMES_DIR." >&2
  echo "  - If Hermes isn't installed yet, use ./install.sh instead - this" >&2
  echo "    script only syncs content onto an *existing* agent." >&2
  exit 1
fi

echo "==> Hermes agent directory: $HERMES_DIR"

FOUND_CATEGORIES=()
for category in "${CATEGORIES[@]}"; do
  if [[ -d "$OVERLAY_DIR/$category" ]]; then
    FOUND_CATEGORIES+=("$category")
  fi
done

if [[ ${#FOUND_CATEGORIES[@]} -eq 0 ]]; then
  echo "  - Nothing to sync: no overlay/{${CATEGORIES[*]}} directories have content in this repo yet."
  exit 0
fi

echo "  - Will sync: ${FOUND_CATEGORIES[*]}"
if [[ "$DRY_RUN" == true ]]; then
  echo "  - (--dry-run: showing what would happen, nothing will be changed)"
fi

if [[ "$ASSUME_YES" != true && "$DRY_RUN" != true ]]; then
  reply=""
  read -r -p "Overwrite matching content under $HERMES_DIR? [y/N] " reply || true
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# skills/ gets special handling (mirrors overlay/install/05-* logic this
# script replaces): only directories containing a SKILL.md are installed,
# under a skills/custom/ subfolder, so a stray README.md alongside the
# skill directories in overlay/skills/custom/ doesn't get copied in too.
sync_skills() {
  local src="$OVERLAY_DIR/skills/custom" target="$HERMES_DIR/skills/custom"
  [[ -d "$src" ]] || return 0

  shopt -s nullglob
  local skill_dirs=("$src"/*/)
  shopt -u nullglob

  for skill_dir in "${skill_dirs[@]}"; do
    local name; name="$(basename "$skill_dir")"
    if [[ ! -f "${skill_dir}SKILL.md" ]]; then
      echo "    - skills: skipping $name (no SKILL.md)"
      continue
    fi
    if [[ "$DRY_RUN" == true ]]; then
      echo "    - skills: would install $name -> $target/$name"
    else
      mkdir -p "$target"
      rm -rf "${target:?}/${name}"
      cp -r "$skill_dir" "$target/$name"
      echo "    - skills: installed $name"
    fi
  done
}

# memories/, cron/, hooks/: straight mirror, whole directory tree,
# whenever this repo actually has content for them.
sync_dir_category() {
  local category="$1"
  local src="$OVERLAY_DIR/$category" target="$HERMES_DIR/$category"
  [[ -d "$src" ]] || return 0

  if [[ "$DRY_RUN" == true ]]; then
    echo "    - $category: would mirror $src -> $target"
  else
    mkdir -p "$target"
    cp -r "$src"/. "$target"/
    echo "    - $category: synced"
  fi
}

for category in "${FOUND_CATEGORIES[@]}"; do
  echo "  - Category: $category"
  if [[ "$category" == "skills" ]]; then
    sync_skills
  else
    sync_dir_category "$category"
  fi
done

if [[ "$DRY_RUN" == true ]]; then
  echo "==> Dry run complete, nothing was changed."
else
  echo "==> Sync complete."
fi
