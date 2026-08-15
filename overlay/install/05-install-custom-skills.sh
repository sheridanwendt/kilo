#!/usr/bin/env bash
# Copies this repo's custom Hermes skills (overlay/skills/custom/<name>/,
# each containing a SKILL.md plus any supporting reference files) into
# Hermes's skill search path, so they're available alongside the 40+
# built-in skills and anything Hermes auto-creates.
#
# TARGET_DIR below is a best-effort assumption, HIGH RISK / not yet
# confirmed against Hermes's actual skill-loading behavior — see
# docs/open-questions.md #11. A real instance's ~/.hermes/skills/ was
# observed to contain only bundled category folders (email, productivity,
# etc.) plus .bundled_manifest/.usage.json bookkeeping files, no custom/
# folder — which doesn't confirm this path works, and the presence of a
# manifest raises the possibility Hermes expects skills to be registered
# (e.g. via a `hermes skill install` command) rather than just dropped in
# a folder. Before relying on this for anything real: confirm Hermes
# actually surfaces a skill installed this way, and that it survives a
# `hermes update` run. If it doesn't work, fix TARGET_DIR (or replace this
# script with a call to whatever registration command Hermes provides) and
# update that doc entry.
#
# Linux/WSL2 only (native Windows install is out of scope, see ADR-0007) —
# $HOME here always resolves to the Linux-side ~/.hermes, never
# %LOCALAPPDATA%\hermes.
#
# Idempotent: each skill's target directory is fully replaced from the
# repo's copy on every run, so edits to a skill (or removing one from
# overlay/skills/custom/) are reflected on re-install.
set -euo pipefail

: "${HPA_OVERLAY_DIR:?must be set by install.sh}"

SRC_DIR="$HPA_OVERLAY_DIR/skills/custom"
TARGET_DIR="$HOME/.hermes/skills/custom"

mkdir -p "$TARGET_DIR"

shopt -s nullglob
SKILL_DIRS=("$SRC_DIR"/*/)
shopt -u nullglob

if [[ ${#SKILL_DIRS[@]} -eq 0 ]]; then
  echo "  - No custom skill directories found in $SRC_DIR, nothing to install."
  exit 0
fi

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name="$(basename "$skill_dir")"
  if [[ ! -f "${skill_dir}SKILL.md" ]]; then
    echo "  - Skipping $skill_name (no SKILL.md)"
    continue
  fi
  echo "  - Installing skill: $skill_name"
  rm -rf "${TARGET_DIR:?}/${skill_name}"
  cp -r "$skill_dir" "$TARGET_DIR/$skill_name"
done

echo "  - Custom skills installed to $TARGET_DIR"
