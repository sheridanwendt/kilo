#!/usr/bin/env bash
# Installs Ollama as the default, offline, free local model provider.
# Enables it as a systemd service (starts at boot) and pre-pulls a baseline
# model so the very first boot works with zero network access.
set -euo pipefail

HPA_OLLAMA_CONTEXT_LENGTH="${HPA_OLLAMA_CONTEXT_LENGTH:-65536}"  # Hermes requires >=64k context

# Model size is a deliberately adjustable placeholder (see CLAUDE.md
# "Performance priorities"): prefer a smaller model on RAM-constrained
# hardware over forcing one size everywhere. An explicit HPA_LOCAL_MODEL
# always wins; only auto-pick when the caller hasn't set one.
if [[ -z "${HPA_LOCAL_MODEL:-}" ]]; then
  MEM_GB=0
  if command -v free >/dev/null 2>&1; then
    MEM_GB=$(( $(free -m | awk '/^Mem:/{print $2}') / 1024 ))
  fi
  if [[ "$MEM_GB" -gt 0 && "$MEM_GB" -lt 8 ]]; then
    HPA_LOCAL_MODEL="qwen2.5:7b"
    echo "  - Detected ~${MEM_GB}GB RAM; auto-selecting a smaller model: ${HPA_LOCAL_MODEL}" \
         "(override with HPA_LOCAL_MODEL=... if you want a different one)"
  else
    HPA_LOCAL_MODEL="qwen2.5:14b"
  fi
fi

NEED_OLLAMA_INSTALL=false
if ! command -v ollama >/dev/null 2>&1; then
  NEED_OLLAMA_INSTALL=true
elif command -v systemctl >/dev/null 2>&1 && ! systemctl cat ollama.service >/dev/null 2>&1; then
  # The `ollama` binary exists but there's no ollama.service unit anywhere in
  # systemd's search path (checked via `systemctl cat`, which works
  # regardless of which of the several standard unit directories it lives
  # in) — a partial/manual install left the binary without the service the
  # rest of this script depends on. The official installer is safe to
  # re-run and will (re)create the missing unit.
  echo "  - ollama binary found but no ollama.service systemd unit; re-running installer to fix"
  NEED_OLLAMA_INSTALL=true
fi

if [[ "$NEED_OLLAMA_INSTALL" == true ]]; then
  echo "  - Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "  - Ollama already installed ($(ollama --version 2>/dev/null || echo 'version unknown'))"
fi

if command -v systemctl >/dev/null 2>&1; then
  echo "  - Enabling ollama.service at boot"
  sudo systemctl enable --now ollama

  # Make sure Ollama exposes enough context for Hermes's tool-calling needs.
  # Ollama truncates context by default; override it explicitly.
  echo "  - Setting OLLAMA_CONTEXT_LENGTH=${HPA_OLLAMA_CONTEXT_LENGTH} via systemd drop-in"
  sudo mkdir -p /etc/systemd/system/ollama.service.d
  cat <<EOF | sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=${HPA_OLLAMA_CONTEXT_LENGTH}"
EOF
  sudo systemctl daemon-reload
  sudo systemctl restart ollama
else
  echo "  - No systemd on this host (macOS?). Start Ollama manually or via 'brew services start ollama'."
fi

echo -n "  - Waiting for Ollama API to come up"
OLLAMA_UP=false
for i in $(seq 1 30); do
  if curl -fsS http://localhost:11434/api/version >/dev/null 2>&1; then
    OLLAMA_UP=true
    break
  fi
  echo -n "."
  sleep 1
done
if [[ "$OLLAMA_UP" == true ]]; then
  echo " ready."
else
  echo " still not responding after 30s, continuing anyway."
fi

echo "  - Pulling local model: ${HPA_LOCAL_MODEL} (override with HPA_LOCAL_MODEL for your hardware)"
# Model pulls can be several GB over a slow/flaky connection on a fresh
# machine; retry a few times rather than failing the whole install on one
# transient network error.
PULL_OK=false
for attempt in 1 2 3; do
  if ollama pull "${HPA_LOCAL_MODEL}"; then
    PULL_OK=true
    break
  fi
  echo "  ! Model pull attempt ${attempt}/3 failed, retrying..." >&2
  sleep 5
done
if [[ "$PULL_OK" != true ]]; then
  echo "  ! Failed to pull ${HPA_LOCAL_MODEL} after 3 attempts. Check network/disk" >&2
  echo "    space, then retry manually with: ollama pull ${HPA_LOCAL_MODEL}" >&2
  exit 1
fi

echo "  - Ollama ready at http://localhost:11434/v1 (no API key, fully offline)."
