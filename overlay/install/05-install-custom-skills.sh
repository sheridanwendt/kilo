#!/usr/bin/env bash
# Copies this repo's custom Hermes skills (overlay/skills/custom/<name>/,
# each containing a SKILL.md plus any supporting reference files) into
# Hermes's skill search path, so they're available alongside the 40+
# built-in skills and anything Hermes auto-creates.
#
# TARGET_DIR below is a best-effort assumption (agentskills.io-standard
# skills live somewhere under ~/.hermes/, mirroring how config.yaml and
# skill memory already live there), not yet confirmed against Hermes's
# actual skill-loading behavior on real hardware — see
# docs/open-questions.md. If Hermes turns out to look elsewhere, fix
# TARGET_DIR here and update that doc entry.
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
