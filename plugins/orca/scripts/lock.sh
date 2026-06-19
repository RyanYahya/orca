#!/bin/bash
# Acquire the workflow lock for a given actor.
# Usage: bash .orca/scripts/lock.sh <actor>
# Exits 0 if the lock is acquired, 1 if held by another live driver.
# Stale locks (older than ORCA_LOCK_TTL seconds, default 3600) auto-release.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

ACTOR="${1:-unknown}"
TTL="${ORCA_LOCK_TTL:-3600}"

mkdir -p "$WORKFLOW_DIR"

NOW_EPOCH=$(date +%s)
LOCK_TMP="$WORKFLOW_DIR/.lock.$$"
trap 'rm -f "$LOCK_TMP"' EXIT

if [[ -f "$LOCK_FILE" ]]; then
  HELD_BY=$(jq -r '.actor // "unknown"' "$LOCK_FILE" 2>/dev/null || echo "unknown")
  STARTED_EPOCH=$(jq -r '.startedEpoch // 0' "$LOCK_FILE" 2>/dev/null || echo 0)
  case "$STARTED_EPOCH" in
    ''|*[!0-9]*) STARTED_EPOCH=0 ;;
  esac

  AGE=$(( NOW_EPOCH - STARTED_EPOCH ))
  if [[ $AGE -lt $TTL ]]; then
    STARTED_HUMAN=$(jq -r '.started // ""' "$LOCK_FILE" 2>/dev/null || echo "")
    echo "ERROR: workflow locked by '$HELD_BY' since $STARTED_HUMAN (age ${AGE}s)" >&2
    echo "       Set ORCA_LOCK_TTL or remove .orca/workflows/current/.lock if stuck." >&2
    exit 1
  fi
  echo "warn: stale lock from '$HELD_BY' (age ${AGE}s); releasing" >&2
  rm -f "$LOCK_FILE"
fi

# Built with jq so an actor/host containing quotes/backslashes can't corrupt the lock JSON.
jq -n --arg actor "$ACTOR" --argjson pid "$$" \
      --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson epoch "$NOW_EPOCH" \
      --arg host "$(hostname -s 2>/dev/null || hostname)" \
      '{actor: $actor, pid: $pid, started: $started, startedEpoch: $epoch, host: $host}' > "$LOCK_TMP"

if ! ( set -o noclobber; cat "$LOCK_TMP" > "$LOCK_FILE" ) 2>/dev/null; then
  HELD_BY=$(jq -r '.actor // "unknown"' "$LOCK_FILE" 2>/dev/null || echo "unknown")
  STARTED_HUMAN=$(jq -r '.started // ""' "$LOCK_FILE" 2>/dev/null || echo "")
  echo "ERROR: workflow locked by '$HELD_BY' since $STARTED_HUMAN" >&2
  exit 1
fi

echo "lock acquired: $ACTOR"
