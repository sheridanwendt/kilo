#!/usr/bin/env bash
# Installs the baseline OS packages every later install step assumes are
# present. Runs first. Safe to re-run — `apt-get install` on already-
# installed packages is a no-op, so this doesn't break idempotency.
#
# Why this exists: a genuinely fresh/minimal Ubuntu install (especially
# minimal cloud images) frequently ships without curl, git, or a working
# pip. Without this step, 01-install-ollama.sh, 02-install-hermes.sh, and
# 03-apply-profile.sh can all fail on a truly clean machine.
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "  ! No apt-get on this host (not Debian/Ubuntu?). Skipping automatic" >&2
  echo "    prereq install — make sure curl, ca-certificates, git, python3," >&2
  echo "    python3-pip, python3-venv, and a YAML library for python3 are" >&2
  echo "    present some other way before continuing." >&2
  exit 0
fi

echo "  - Updating apt package index (output below; can take a moment on a fresh machine)"
APT_UPDATE_LOG="$(mktemp)"
trap 'rm -f "$APT_UPDATE_LOG"' EXIT
if ! sudo apt-get update 2>&1 | tee "$APT_UPDATE_LOG"; then
  :
fi
if grep -qE "Network is unreachable|Could not connect|Could not resolve|Connection timed out" "$APT_UPDATE_LOG"; then
  # Common on networks/hosts with a broken or absent IPv6 route: apt tries
  # the IPv6 addresses Canonical's mirror redirector hands out first, those
  # time out/fail, and it never gets to a working IPv4 address on its own.
  # Retrying with IPv4 forced is the standard fix.
  echo "  ! apt-get update hit network errors (looks like a broken/absent IPv6" >&2
  echo "    route to Ubuntu's mirrors). Retrying with IPv4 forced..." >&2
  sudo apt-get update -o Acquire::ForceIPv4=true
fi

echo "  - Installing baseline packages (curl, git, python3 + pip/venv/yaml)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  ca-certificates \
  git \
  gnupg \
  lsb-release \
  python3 \
  python3-pip \
  python3-venv \
  python3-yaml

# python3-yaml (apt) gives 03-apply-profile.sh a working `import yaml` with
# zero pip involvement in the common case — see docs/decisions.md ADR-0012
# for why this matters (pip's --break-system-packages flag only exists on
# pip >=23.0.1 / Ubuntu 24.04+, and errors out on Ubuntu 22.04's older pip).

DISTRO="$(lsb_release -ds 2>/dev/null || echo 'unknown distro')"
echo "  - Prereqs ready (${DISTRO})."

# Soft resource sanity checks — warnings only, never block install. These
# exist because the default local model (qwen2.5:14b) needs real RAM/disk
# headroom, and a small VPS or thin VM can silently fail (OOM, disk full)
# much later in the install with a confusing error otherwise.
if command -v free >/dev/null 2>&1; then
  MEM_GB=$(( $(free -m | awk '/^Mem:/{print $2}') / 1024 ))
  if [[ "$MEM_GB" -lt 8 ]]; then
    echo "  ! Warning: ~${MEM_GB}GB RAM detected. The default local model" >&2
    echo "    (qwen2.5:14b) typically wants 8-10GB+ free to run well." >&2
    echo "    Consider: HPA_LOCAL_MODEL=qwen2.5:7b ./install.sh ..." >&2
  fi
fi
if command -v df >/dev/null 2>&1; then
  AVAIL_GB=$(( $(df -Pk "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
  if [[ "$AVAIL_GB" -lt 20 ]]; then
    echo "  ! Warning: ~${AVAIL_GB}GB free disk on \$HOME's filesystem. Hermes" >&2
    echo "    + a local model + logs can need 15-20GB+. Free up space if" >&2
    echo "    the install fails partway through a model pull." >&2
  fi
fi
