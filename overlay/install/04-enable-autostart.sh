#!/usr/bin/env bash
# Registers Hermes as a boot-time systemd service, ordered to start after
# Ollama so the default local model backend is always up first.
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "  ! No systemd on this host. On macOS, use 'hermes gateway install' (user launchd agent) instead." >&2
  exit 0
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "  ! hermes CLI not found; run 02-install-hermes.sh first." >&2
  exit 1
fi

echo "  - Registering hermes-gateway as a system service (starts at boot, auto-restarts)"
sudo hermes gateway install --system

echo "  - Ordering hermes-gateway after ollama.service"
sudo mkdir -p /etc/systemd/system/hermes-gateway.service.d
cat <<EOF | sudo tee /etc/systemd/system/hermes-gateway.service.d/override.conf >/dev/null
[Unit]
After=ollama.service
Requires=ollama.service
EOF

sudo systemctl daemon-reload
sudo systemctl enable hermes-gateway
sudo systemctl restart hermes-gateway

echo "  - Autostart registered. Check with: systemctl status ollama hermes-gateway"
echo "  - Logs: journalctl -u hermes-gateway -f"
