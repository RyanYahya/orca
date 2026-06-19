#!/bin/bash
# Mark a phase complete and advance currentPhase safely.
# Usage: complete-phase.sh <phase-id> [--actor <actor>]

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

PHASE_ID="${1:-}"
[[ -n "$PHASE_ID" ]] || { echo "usage: complete-phase.sh <phase-id> [--actor <actor>]" >&2; exit 1; }
shift || true
ACTOR="executor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor) ACTOR="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    -h|--help) echo "usage: complete-phase.sh <phase-id> [--actor <actor>]"; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }
jq -e --arg pid "$PHASE_ID" 'any(.phases[]?; .id == $pid)' "$STATUS_FILE" >/dev/null || { echo "ERROR: phase $PHASE_ID not found" >&2; exit 1; }

AUDIT_STATUS=$(jq -r --arg pid "$PHASE_ID" '.phases[] | select(.id == $pid) | .audit.status // ""' "$STATUS_FILE")
if [[ "$AUDIT_STATUS" != "APPROVED" ]]; then
  echo "ERROR: phase $PHASE_ID audit is not APPROVED; refusing to complete" >&2
  exit 1
fi

TS="$(get_timestamp)"
jq --arg pid "$PHASE_ID" --arg ts "$TS" --arg actor "$ACTOR" '
  (.phases | map(.id) | index($pid)) as $idx
  | .phases[$idx].status = "completed"
  | .currentPhase = (if ((.currentPhase // 0) < ($idx + 1)) then ($idx + 1) else .currentPhase end)
  | .status = (if ([.phases[] | select(.status != "completed")] | length) == 0 then "COMPLETED" else "PENDING" end)
  | .lastUpdated = $ts
  | .log += [{"time": $ts, "actor": $actor, "action": "Phase \($pid) completed"}]
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "completed $PHASE_ID"
