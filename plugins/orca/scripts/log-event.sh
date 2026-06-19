#!/bin/bash
# Append an entry to status.json.log[].
# Usage: bash .orca/scripts/log-event.sh <actor> <action>
# Keeps the log capped at ORCA_LOG_MAX entries (default 500) — older entries are dropped.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

ACTOR="${1:-unknown}"
ACTION="${2:-}"
[[ -n "$ACTION" ]] || { echo "usage: log-event.sh <actor> <action>" >&2; exit 1; }

workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }

MAX="${ORCA_LOG_MAX:-500}"

jq --arg actor "$ACTOR" --arg action "$ACTION" --arg ts "$(get_timestamp)" --argjson max "$MAX" '
  .log += [{"time": $ts, "actor": $actor, "action": $action}]
  | .log = (.log | if length > $max then .[length - $max:] else . end)
  | .lastUpdated = $ts
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
