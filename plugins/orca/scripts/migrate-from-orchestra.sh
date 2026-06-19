#!/bin/bash
# One-time migration: move an in-flight orchestra workflow into orca.
# orca and orchestra share the same on-disk state format, so this just relocates
# .orchestra/workflows/ -> .orca/workflows/ without touching the contents.
#
# Usage: bash .orca/scripts/migrate-from-orchestra.sh
# Safe by default: refuses to overwrite an existing .orca/workflows/current/.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

SRC="$PROJECT_ROOT/.orchestra/workflows"
DST="$PROJECT_ROOT/.orca/workflows"

if [[ ! -d "$SRC" ]]; then
  echo "Nothing to migrate: no .orchestra/workflows/ found."
  exit 0
fi

mkdir -p "$DST/current" "$DST/archived"

# Migrate the active workflow, if any.
if [[ -f "$SRC/current/status.json" ]]; then
  if [[ -f "$DST/current/status.json" ]]; then
    echo "ERROR: .orca/workflows/current/ already has an active workflow." >&2
    echo "       Archive it (\$orca archive) before migrating, to avoid clobbering." >&2
    exit 1
  fi
  cp -R "$SRC/current/." "$DST/current/"
  # Drop any stale lock carried over from the orchestra session.
  rm -f "$DST/current/.lock"
  echo "Migrated active workflow: $(jq -r '.task' "$DST/current/status.json" 2>/dev/null || echo '?')"
fi

# Migrate archived workflows (skip ones that already exist at the destination).
if [[ -d "$SRC/archived" ]]; then
  for dir in "$SRC/archived"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    if [[ -e "$DST/archived/$name" ]]; then
      echo "skip (exists): archived/$name"
      continue
    fi
    cp -R "$dir" "$DST/archived/$name"
    echo "Migrated archive: $name"
  done
fi

echo
echo "Done. Original .orchestra/ is left untouched — remove it once you've confirmed the migration."
echo "Note: phase commits made under orchestra keep their original 'orchestra(P#)' messages; that's cosmetic."
