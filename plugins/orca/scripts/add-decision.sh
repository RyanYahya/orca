#!/bin/bash
# Add or update a decision in decisions.json. Re-renders Decisions.md.
#
# Usage:
#   add-decision.sh add <question> [recommendation]
#   add-decision.sh answer <id> <answer> [answered_by]
#
# `add` allocates the next D### id and creates a pending decision.
# `answer` records the chosen answer (and optional actor) on an existing decision.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

JSON_FILE="$WORKFLOW_DIR/decisions.json"

if ! workflow_exists || [[ ! -f "$JSON_FILE" ]]; then
  echo "ERROR: no decisions.json (workflow not initialized?)" >&2
  exit 1
fi

CMD="${1:-}"

case "$CMD" in
  add)
    QUESTION="${2:-}"
    REC="${3:-}"
    [[ -n "$QUESTION" ]] || { echo "usage: add <question> [recommendation]" >&2; exit 1; }
    NEXT_NUM=$(jq '[.decisions[].id | sub("^D"; "") | tonumber] | (max // 0) + 1' "$JSON_FILE")
    ID=$(printf "D%03d" "$NEXT_NUM")
    jq --arg id "$ID" --arg q "$QUESTION" --arg rec "$REC" '
      .decisions += [{
        "id": $id,
        "question": $q,
        "options": [],
        "recommendation": (if $rec == "" then null else $rec end),
        "answer": null,
        "answeredBy": null,
        "answeredAt": null
      }]
    ' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
    bash "$SCRIPT_DIR/render-decisions.sh" >/dev/null
    echo "$ID"
    ;;
  answer)
    ID="${2:-}"
    ANS="${3:-}"
    BY="${4:-user}"
    [[ -n "$ID" && -n "$ANS" ]] || { echo "usage: answer <id> <answer> [answered_by]" >&2; exit 1; }
    jq --arg id "$ID" --arg ans "$ANS" --arg by "$BY" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
      .decisions = (.decisions | map(
        if .id == $id then
          .answer = $ans | .answeredBy = $by | .answeredAt = $at
        else . end
      ))
    ' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
    bash "$SCRIPT_DIR/render-decisions.sh" >/dev/null
    echo "answered $ID"
    ;;
  *)
    echo "usage: $0 {add|answer} ..." >&2
    exit 1
    ;;
esac
