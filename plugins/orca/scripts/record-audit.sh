#!/bin/bash
# Record phase audit results in status.json.
# Usage:
#   record-audit.sh <phase-id> --approved [--auto-fixed N] [--surfaced N] [--learned N]
#   record-audit.sh <phase-id> --issues [--issues-file PATH]
#
# --issues sets the top-level status to BLOCKED so the runner halts and the user
# (or `$orca resolve`) can address the findings before the phase is committed.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

PHASE_ID="${1:-}"
[[ -n "$PHASE_ID" ]] || { echo "usage: record-audit.sh <phase-id> (--approved|--issues) [options]" >&2; exit 1; }
shift || true

STATUS=""
AUTO_FIXED="0"
SURFACED="0"
LEARNED="0"
ISSUES_FILE=""
ACTOR="auditor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --approved) STATUS="APPROVED"; shift ;;
    --issues) STATUS="ISSUES"; shift ;;
    --auto-fixed) AUTO_FIXED="${2:-0}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --surfaced) SURFACED="${2:-0}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --learned) LEARNED="${2:-0}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --issues-file) ISSUES_FILE="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    --actor) ACTOR="${2:-}"; shift "$(( $# >= 2 ? 2 : 1 ))" ;;
    -h|--help) echo "usage: record-audit.sh <phase-id> (--approved|--issues) [options]"; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ "$STATUS" == "APPROVED" || "$STATUS" == "ISSUES" ]] || { echo "ERROR: pass --approved or --issues" >&2; exit 1; }
workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }

jq -e --arg pid "$PHASE_ID" 'any(.phases[]?; .id == $pid)' "$STATUS_FILE" >/dev/null || { echo "ERROR: phase $PHASE_ID not found" >&2; exit 1; }

TS="$(get_timestamp)"
if [[ "$STATUS" == "APPROVED" ]]; then
  jq --arg pid "$PHASE_ID" --arg ts "$TS" --arg actor "$ACTOR" \
     --argjson fixed "$AUTO_FIXED" --argjson surfaced "$SURFACED" --argjson learned "$LEARNED" '
    .phases = (.phases | map(if .id == $pid then
      .audit = {"status": "APPROVED", "autoFixed": $fixed, "surfaced": $surfaced, "learned": $learned, "at": $ts}
    else . end))
    | .lastUpdated = $ts
    | .log += [{"time": $ts, "actor": $actor, "action": "Phase \($pid) audit: APPROVED (auto-fixed: \($fixed), surfaced: \($surfaced), learned: \($learned))"}]
  ' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "recorded audit approval for $PHASE_ID"
else
  jq --arg pid "$PHASE_ID" --arg ts "$TS" --arg actor "$ACTOR" --arg issues "$ISSUES_FILE" '
    .phases = (.phases | map(if .id == $pid then
      .audit = {"status": "ISSUES", "issuesFile": $issues, "at": $ts}
    else . end))
    | .status = "BLOCKED"
    | .lastUpdated = $ts
    | .log += [{"time": $ts, "actor": $actor, "action": "Phase \($pid) audit FAILED - see \($issues)"}]
  ' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "recorded audit issues for $PHASE_ID"
fi
