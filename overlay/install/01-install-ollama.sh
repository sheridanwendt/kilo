#!/usr/bin/env bash
# Installs Ollama as the default, offline, free local model provider.
# Enables it as a systemd service (starts at boot) and pre-pulls a baseline
# model so the very first boot works with zero network access.
set -euo pipefail

HPA_OLLAMA_CONTEXT_LENGTH="${HPA_OLLAMA_CONTEXT_LENGTH:-65536}"  # Hermes requires >=64k context

# Where Ollama stores pulled model blobs. Pinned explicitly (rather than left
# to Ollama's implicit default) so it's deterministic regardless of *how*
# ollama.service ends up running. Without this, `ollama serve` launched
# directly by a human (e.g. after manually killing the process instead of
# `sudo systemctl restart ollama`) defaults to that user's own
# ~/.ollama/models — a different, empty directory from the one the systemd
# service (running as the `ollama` system user) actually pulled into. That
# looks exactly like "my models got erased" in `ollama ls`, even though the
# original blobs are untouched at the path below.
HPA_OLLAMA_MODELS_DIR="${HPA_OLLAMA_MODELS_DIR:-/usr/share/ollama/.ollama/models}"

# Model choice is a deliberately adjustable placeholder (see CLAUDE.md
# "Performance priorities"), not a fixed requirement. An explicit
# HPA_LOCAL_MODEL always wins over this default.
#
# qwen3.5:9b confirmed working end-to-end on real hardware (Sheridan's
# on-prem box "stick", ~7GB RAM) 2026-07-24 — replaces the earlier
# qwen2.5:14b default, which turned out to have only a 32,768-token native
# context (see docs/open-questions.md #6): below Hermes's 64k minimum, and
# not safely extensible without YaRN rope-scaling tricks Hermes wasn't
# actually configured to use. qwen3.5:9b's native context is 262,144
# tokens, comfortably covering the HPA_OLLAMA_CONTEXT_LENGTH window above
# with no extrapolation involved. The previous RAM-tiered 7b/14b split is
# dropped for now since only this one size is confirmed; reintroduce a
# smaller/larger tier here if a specific constrained/high-RAM profile
# needs it later.
HPA_LOCAL_MODEL="${HPA_LOCAL_MODEL:-qwen3.5:9b}"

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
  # Ollama truncates context by default; override it explicitly. Also pin
  # OLLAMA_MODELS explicitly (see comment above HPA_OLLAMA_MODELS_DIR) so the
  # storage path is deterministic no matter how the process gets (re)started.
  echo "  - Setting OLLAMA_CONTEXT_LENGTH=${HPA_OLLAMA_CONTEXT_LENGTH}, OLLAMA_MODELS=${HPA_OLLAMA_MODELS_DIR} via systemd drop-in"
  sudo mkdir -p /etc/systemd/system/ollama.service.d
  cat <<EOF | sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=${HPA_OLLAMA_CONTEXT_LENGTH}"
Environment="OLLAMA_MODELS=${HPA_OLLAMA_MODELS_DIR}"
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

# `ollama pull` re-checks the registry manifest over the network even when
# the model is already fully cached locally — a needless round trip (and a
# needless network dependency) on every re-install once the model is
# already there. Skip it entirely if it's already present. This assumes
# HPA_LOCAL_MODEL always carries an explicit tag (the defaults above do;
# so should any override), since `ollama list` prints the tag Ollama
# actually stored it under.
if ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qxF "${HPA_LOCAL_MODEL}"; then
  echo "  - Model already present locally: ${HPA_LOCAL_MODEL}, skipping pull"
else
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
fi

echo "  - Ollama ready at http://localhost:11434/v1 (no API key, fully offline)."
