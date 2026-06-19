#!/bin/bash
# Release the workflow lock if held by the given actor.
# Usage: bash .orca/scripts/unlock.sh <actor>
# Always exits 0 (releasing a lock you don't own is a no-op, not an error).

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

ACTOR="${1:-unknown}"

if [[ ! -f "$LOCK_FILE" ]]; then
  exit 0
fi

HELD_BY=$(jq -r '.actor // "unknown"' "$LOCK_FILE" 2>/dev/null || echo "unknown")

if [[ "$HELD_BY" == "$ACTOR" ]]; then
  rm -f "$LOCK_FILE"
  echo "lock released: $ACTOR"
else
  echo "warn: lock held by '$HELD_BY' (not '$ACTOR'); not releasing" >&2
fi
