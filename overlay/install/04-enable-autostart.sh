#!/usr/bin/env bash
# Registers Hermes as a boot-time systemd service, ordered to start after
# Ollama so the default local model backend is always up first.
#
# Two easy-to-miss failure modes this script deliberately guards against
# (see docs/decisions.md ADR-0012):
#   1. Upstream Hermes's installer deliberately avoids sudo and installs
#      into the invoking user's home directory. Plain `sudo hermes ...`
#      resets PATH and won't find that binary, failing with "command not
#      found" even though `hermes` works fine unprivileged. We resolve the
#      absolute path ourselves and explicitly preserve PATH under sudo.
#   2. A system-level systemd service defaults to running as root, which
#      means it would read /root/.hermes/config.yaml instead of the
#      installing user's ~/.hermes/config.yaml that 03-apply-profile.sh
#      just wrote — silently starting on an empty/default config instead
#      of the local-first profile. We pin User=/Group=/HOME= explicitly to
#      the installing user to prevent that.
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "  ! No systemd on this host. On macOS, use 'hermes gateway install' (user launchd agent) instead." >&2
  exit 0
fi

HERMES_BIN="$(command -v hermes || true)"
if [[ -z "$HERMES_BIN" ]]; then
  echo "  ! hermes CLI not found; run 02-install-hermes.sh first." >&2
  exit 1
fi

INSTALL_USER="${SUDO_USER:-$USER}"
INSTALL_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
if [[ -z "$INSTALL_HOME" ]]; then
  INSTALL_HOME="$HOME"
fi
INSTALL_GROUP="$(id -gn "$INSTALL_USER" 2>/dev/null || echo "$INSTALL_USER")"

echo "  - Registering hermes-gateway as a system service (starts at boot, auto-restarts)"
echo "  - Will run as user '$INSTALL_USER' (home: $INSTALL_HOME) so it reads that user's ~/.hermes"
# Preserve PATH under sudo — see failure mode #1 above.
sudo env "PATH=$PATH" "$HERMES_BIN" gateway install --system

echo "  - Pinning hermes-gateway to run as '$INSTALL_USER' + ordering it after ollama.service"
sudo mkdir -p /etc/systemd/system/hermes-gateway.service.d
cat <<EOF | sudo tee /etc/systemd/system/hermes-gateway.service.d/override.conf >/dev/null
[Unit]
After=ollama.service
Requires=ollama.service

[Service]
User=${INSTALL_USER}
Group=${INSTALL_GROUP}
Environment="HOME=${INSTALL_HOME}"
EOF

sudo systemctl daemon-reload
sudo systemctl enable hermes-gateway
sudo systemctl restart hermes-gateway

echo "  - Autostart registered. Check with: systemctl status ollama hermes-gateway"
echo "  - Verify it's using the right config: sudo systemctl show hermes-gateway -p User -p Environment"
echo "  - Logs: journalctl -u hermes-gateway -f"
