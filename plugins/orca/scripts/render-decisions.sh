#!/bin/bash
# Render decisions.json → Decisions.md (human-readable).
# decisions.json is the canonical store; Decisions.md is generated.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

if ! workflow_exists; then
  echo "ERROR: no active workflow" >&2
  exit 1
fi

JSON_FILE="$WORKFLOW_DIR/decisions.json"
MD_FILE="$WORKFLOW_DIR/Decisions.md"

[[ -f "$JSON_FILE" ]] || { echo "ERROR: decisions.json not found" >&2; exit 1; }

TASK=$(get_task_name)
PENDING=$(jq '[.decisions[] | select(.answer == null or .answer == "")] | length' "$JSON_FILE")

{
  echo "# Decisions Log"
  echo
  echo "> Task: $TASK"
  echo "> Pending: $PENDING"
  echo "> _Generated from decisions.json — do not edit by hand._"
  echo

  echo "## Pending Decisions"
  echo
  PENDING_BLOCK=$(jq -r '
    .decisions[] | select(.answer == null or .answer == "") |
    "### \(.id): \(.question)\n\n" +
    (if (.options // []) | length > 0 then
      "**Options:**\n" + ([.options[] | "- **\(.label)**" + (if .pros then " — pros: " + (.pros | join(", ")) else "" end) + (if .cons then "; cons: " + (.cons | join(", ")) else "" end)] | join("\n")) + "\n\n"
    else "" end) +
    (if .recommendation then "**Recommendation:** \(.recommendation)\n" else "" end)
  ' "$JSON_FILE")
  if [[ -z "$PENDING_BLOCK" ]]; then
    echo "_No pending decisions._"
  else
    echo "$PENDING_BLOCK"
  fi
  echo
  echo "---"
  echo
  echo "## Resolved Decisions"
  echo
  RESOLVED_BLOCK=$(jq -r '
    .decisions[] | select(.answer != null and .answer != "") |
    "### \(.id): \(.question)\n\n" +
    (if .recommendation then "**Recommendation:** \(.recommendation)\n\n" else "" end) +
    "**Answer:** \(.answer)\n" +
    (if .answeredBy then "_Answered by \(.answeredBy)" + (if .answeredAt then " at \(.answeredAt)" else "" end) + "_\n" else "" end)
  ' "$JSON_FILE")
  if [[ -z "$RESOLVED_BLOCK" ]]; then
    echo "_None yet._"
  else
    echo "$RESOLVED_BLOCK"
  fi
} > "$MD_FILE"

echo "rendered → $MD_FILE"
