#!/bin/bash
# Parse Plan.md and rebuild the phases[] array in status.json.
# Plan.md is the source of truth for phase/step structure.
# status.json keeps `done` flags, log[], git data; we merge by step ID.
#
# Plan.md format (strict):
#
#   ### Phase 1: Name of phase
#
#   **Steps:**
#   1. First step description
#   2. Second step description
#
#   **Verify:**
#   - Manual: human verification instructions
#   - Auto: `optional shell command`
#
# Phase IDs: P1, P2, ...   Step IDs: P1.S1, P1.S2, ...
# IDs are positional; if you reorder steps, status flags realign by position.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

if ! workflow_exists; then
  echo "ERROR: no active workflow" >&2
  exit 1
fi

PLAN_FILE="$WORKFLOW_DIR/Plan.md"
[[ -f "$PLAN_FILE" ]] || { echo "ERROR: Plan.md not found" >&2; exit 1; }

# Extract phases via awk into a temp JSON file.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

awk '
  BEGIN {
    phase_idx = 0
    in_steps = 0
    in_verify = 0
    in_comment = 0
    print "["
    first_phase = 1
  }
  /^[[:space:]]*<!--/ {
    if ($0 !~ /-->/) in_comment = 1
    next
  }
  in_comment {
    if ($0 ~ /-->/) in_comment = 0
    next
  }
  /^### Phase [0-9]+:/ {
    # Close previous phase if any
    if (phase_idx > 0) {
      close_phase()
    }
    phase_idx++
    name = $0
    sub(/^### Phase [0-9]+:[[:space:]]*/, "", name)
    gsub(/"/, "\\\"", name)
    if (!first_phase) print ","
    first_phase = 0
    printf "  {\n    \"id\": \"P%d\",\n    \"name\": \"%s\",\n    \"status\": \"pending\",\n    \"steps\": [", phase_idx, name
    step_idx = 0
    in_steps = 0
    in_verify = 0
    verify_manual = ""
    verify_auto = ""
    next
  }
  /^\*\*Steps:\*\*/ { in_steps = 1; in_verify = 0; next }
  /^\*\*Verify:\*\*/ { in_steps = 0; in_verify = 1; next }
  /^\*\*[A-Za-z]/ { in_steps = 0; in_verify = 0; next }
  /^### / && phase_idx > 0 { in_steps = 0; in_verify = 0 }

  in_steps && /^[[:space:]]*[0-9]+\./ {
    text = $0
    sub(/^[[:space:]]*[0-9]+\.[[:space:]]*/, "", text)
    gsub(/"/, "\\\"", text)
    gsub(/\\/, "\\\\", text)
    if (step_idx > 0) printf ","
    step_idx++
    printf "\n      {\"id\": \"P%d.S%d\", \"text\": \"%s\", \"done\": false}", phase_idx, step_idx, text
  }

  in_verify && /^[[:space:]]*-[[:space:]]*Manual:/ {
    t = $0
    sub(/^[[:space:]]*-[[:space:]]*Manual:[[:space:]]*/, "", t)
    gsub(/"/, "\\\"", t)
    verify_manual = t
  }
  in_verify && /^[[:space:]]*-[[:space:]]*Auto:/ {
    t = $0
    sub(/^[[:space:]]*-[[:space:]]*Auto:[[:space:]]*/, "", t)
    # Strip surrounding backticks if present
    gsub(/`/, "", t)
    gsub(/"/, "\\\"", t)
    verify_auto = t
  }

  function close_phase() {
    printf "\n    ],\n"
    printf "    \"verify\": {\"manual\": \"%s\", \"auto\": \"%s\"}\n", verify_manual, verify_auto
    printf "  }"
    verify_manual = ""
    verify_auto = ""
  }

  END {
    if (phase_idx > 0) close_phase()
    print "\n]"
  }
' "$PLAN_FILE" > "$TMP"

# Validate
if ! jq empty "$TMP" >/dev/null 2>&1; then
  echo "ERROR: parser produced invalid JSON; check Plan.md format" >&2
  cat "$TMP" >&2
  exit 1
fi

NEW_PHASES=$(cat "$TMP")
TOTAL=$(echo "$NEW_PHASES" | jq 'length')

# Merge: for each new phase/step, preserve existing `done` and phase `status` if IDs match.
MERGED=$(jq --argjson new "$NEW_PHASES" '
  ((.phases // []) | map({key: .id, value: .}) | from_entries) as $old_idx
  | $new | map(
      . as $np
      | ($old_idx[$np.id] // null) as $op
      | if $op then
          $np
          | .status = ($op.status // "pending")
          | (($op.steps // []) | map({key: .id, value: .}) | from_entries) as $old_steps
          | .steps = (.steps | map(
              . as $ns
              | ($old_steps[$ns.id] // null) as $os
              | if $os then $ns | .done = ($os.done // false) else $ns end
            ))
        else
          $np
        end
    )
' "$STATUS_FILE")

# Write back: replace phases, update totalPhases
jq --argjson phases "$MERGED" --argjson total "$TOTAL" --arg ts "$(get_timestamp)" '
  .phases = $phases
  | .totalPhases = $total
  | .lastUpdated = $ts
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "parsed Plan.md → $TOTAL phases"
