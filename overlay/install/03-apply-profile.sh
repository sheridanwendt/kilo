#!/usr/bin/env bash
# Deep-merges overlay/config-profiles/default.yaml with the chosen profile's
# overrides and writes the result to ~/.hermes/config.yaml.
set -euo pipefail

: "${HPA_OVERLAY_DIR:?must be set by install.sh}"
: "${HPA_PROFILE_FILE:?must be set by install.sh}"

DEFAULT_FILE="$HPA_OVERLAY_DIR/config-profiles/default.yaml"
HERMES_DIR="$HOME/.hermes"
TARGET_FILE="$HERMES_DIR/config.yaml"

mkdir -p "$HERMES_DIR"

python3 - "$DEFAULT_FILE" "$HPA_PROFILE_FILE" "$TARGET_FILE" <<'PYEOF'
import sys
try:
    import yaml
except ImportError:
    # In the common case this branch never runs: 00-install-prereqs.sh
    # installs the `python3-yaml` apt package first, which makes `import
    # yaml` work with zero pip involvement. This is a fallback for hosts
    # where that step was skipped (e.g. --skip-autostart-style manual runs,
    # or a non-Debian host).
    #
    # pip's --break-system-packages flag only exists on pip >=23.0.1
    # (roughly Ubuntu 24.04+). Passing it to an older pip (e.g. Ubuntu
    # 22.04's default) errors out with "no such option" and would break
    # this whole script. So: try a plain install first, and only add the
    # flag if that specifically fails (which is what a PEP 668
    # "externally-managed-environment" refusal looks like).
    import subprocess

    def pip_install(extra_args):
        return subprocess.run(
            [sys.executable, "-m", "pip", "install", "--quiet", *extra_args, "pyyaml"]
        )

    result = pip_install([])
    if result.returncode != 0:
        result = pip_install(["--break-system-packages"])
    if result.returncode != 0:
        sys.exit(
            "Could not install PyYAML via pip on this system.\n"
            "Fix manually, e.g.:\n"
            "  sudo apt-get install -y python3-yaml\n"
            "then re-run ./install.sh."
        )
    import yaml

default_path, profile_path, target_path = sys.argv[1:4]

def load(path):
    with open(path) as f:
        return yaml.safe_load(f) or {}

def deep_merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result

merged = deep_merge(load(default_path), load(profile_path))

# Back up any existing hand-edited config before overwriting.
import os, shutil, datetime
if os.path.exists(target_path):
    backup = f"{target_path}.bak.{datetime.datetime.now():%Y%m%d%H%M%S}"
    shutil.copy2(target_path, backup)
    print(f"  - Backed up existing config to {backup}")

with open(target_path, "w") as f:
    yaml.safe_dump(merged, f, sort_keys=False)

print(f"  - Wrote merged config to {target_path}")
PYEOF

echo "  - Profile applied: $(basename "$HPA_PROFILE_FILE" .yaml)"
