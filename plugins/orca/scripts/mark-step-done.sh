#!/bin/bash
# Mark one workflow step complete.
# Usage: mark-step-done.sh <phase-id> <step-id> [--actor <actor>]

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

PHASE_ID="${1:-}"
STEP_ID="${2:-}"
shift 2 2>/dev/null || true
ACTOR="executor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor) ACTOR="${2:-}"; [[ -n "$ACTOR" ]] || { echo "ERROR: --actor requires a value" >&2; exit 1; }; shift 2 ;;
    -h|--help) echo "usage: mark-step-done.sh <phase-id> <step-id> [--actor <actor>]"; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PHASE_ID" && -n "$STEP_ID" ]] || { echo "usage: mark-step-done.sh <phase-id> <step-id> [--actor <actor>]" >&2; exit 1; }
workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }

jq -e --arg pid "$PHASE_ID" --arg sid "$STEP_ID" '
  any(.phases[]?; .id == $pid and any(.steps[]?; .id == $sid))
' "$STATUS_FILE" >/dev/null || { echo "ERROR: $STEP_ID not found in $PHASE_ID" >&2; exit 1; }

TS="$(get_timestamp)"
jq --arg pid "$PHASE_ID" --arg sid "$STEP_ID" --arg ts "$TS" --arg actor "$ACTOR" '
  .phases = (.phases | map(if .id == $pid then
    .steps = (.steps | map(if .id == $sid then .done = true else . end))
  else . end))
  | .lastUpdated = $ts
  | .log += [{"time": $ts, "actor": $actor, "action": "step \($sid) done"}]
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "marked $STEP_ID done"
