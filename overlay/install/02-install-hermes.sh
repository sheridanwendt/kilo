#!/usr/bin/env bash
# Installs upstream Hermes Agent via its official one-line installer.
# Pass --update to instead pull upstream updates for an existing install.
set -euo pipefail

UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
fi

if [[ "$UPDATE_MODE" == true ]]; then
  if command -v hermes >/dev/null 2>&1; then
    echo "  - Running 'hermes update'"
    hermes update
  else
    echo "  ! hermes CLI not found, cannot update. Run install.sh without --update first." >&2
    exit 1
  fi
  exit 0
fi

if command -v hermes >/dev/null 2>&1; then
  echo "  - Hermes CLI already installed ($(hermes --version 2>/dev/null || echo 'version unknown')); skipping install, use --update to refresh."
else
  echo "  - Running upstream Hermes Agent installer"
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
fi

# Best-effort version pin note: upstream's installer tracks its own latest release.
# overlay/UPSTREAM_VERSION documents which version this overlay was last validated
# against. If you need a hard pin, clone NousResearch/hermes-agent yourself at that
# tag and adjust this script to install from your local clone instead.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../UPSTREAM_VERSION" ]]; then
  echo "  - This overlay was last validated against: $(cat "$(dirname "${BASH_SOURCE[0]}")/../UPSTREAM_VERSION")"
fi
