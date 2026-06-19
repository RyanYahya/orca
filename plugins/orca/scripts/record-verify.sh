#!/bin/bash
# Record phase verification results in status.json.
# Usage: record-verify.sh <phase-id> --auto PASS|FAIL|SKIP --manual PASS|FAIL|SKIP [--actor <actor>]

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

PHASE_ID="${1:-}"
[[ -n "$PHASE_ID" ]] || { echo "usage: record-verify.sh <phase-id> --auto RESULT --manual RESULT [--actor <actor>]" >&2; exit 1; }
shift || true

AUTO=""
MANUAL=""
ACTOR="executor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --manual) MANUAL="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --actor) ACTOR="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    -h|--help) echo "usage: record-verify.sh <phase-id> --auto RESULT --manual RESULT [--actor <actor>]"; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$AUTO" && -n "$MANUAL" ]] || { echo "ERROR: --auto and --manual are required" >&2; exit 1; }
workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }

jq -e --arg pid "$PHASE_ID" 'any(.phases[]?; .id == $pid)' "$STATUS_FILE" >/dev/null || { echo "ERROR: phase $PHASE_ID not found" >&2; exit 1; }

TS="$(get_timestamp)"
jq --arg pid "$PHASE_ID" --arg auto "$AUTO" --arg manual "$MANUAL" --arg ts "$TS" --arg actor "$ACTOR" '
  .phases = (.phases | map(if .id == $pid then
    .verifyResult = {"auto": $auto, "manual": $manual, "at": $ts}
  else . end))
  | .lastUpdated = $ts
  | .log += [{"time": $ts, "actor": $actor, "action": "Phase \($pid) verify: auto=\($auto) manual=\($manual)"}]
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "recorded verify for $PHASE_ID: auto=$AUTO manual=$MANUAL"
