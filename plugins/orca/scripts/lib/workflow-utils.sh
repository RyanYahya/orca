#!/bin/bash
# Shared helpers for orca workflow scripts.
#
# Installed layout (in the target repo):
#   .orca/scripts/lib/workflow-utils.sh   <- this file
#   .orca/scripts/<command>.sh            <- sourcing scripts
# So PROJECT_ROOT is three levels up from this lib directory.

set -euo pipefail

_ORCA_LIB_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(builtin cd "$_ORCA_LIB_DIR/../../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/.orca/workflows/current"
STATUS_FILE="$WORKFLOW_DIR/status.json"
LOCK_FILE="$WORKFLOW_DIR/.lock"

workflow_exists() {
  [[ -d "$WORKFLOW_DIR" ]] && [[ -f "$STATUS_FILE" ]]
}

get_task_name() {
  workflow_exists && jq -r '.task' "$STATUS_FILE"
}

get_status() {
  workflow_exists && jq -r '.status' "$STATUS_FILE"
}

get_current_phase() {
  workflow_exists && jq -r '.currentPhase' "$STATUS_FILE"
}

get_total_phases() {
  workflow_exists && jq -r '.totalPhases' "$STATUS_FILE"
}

get_progress() {
  if workflow_exists; then
    local done total
    done=$(jq '[.phases[].steps[] | select(.done == true)] | length' "$STATUS_FILE")
    total=$(jq '[.phases[].steps[]] | length' "$STATUS_FILE")
    if [[ "$total" -eq 0 ]]; then
      echo "0"
    else
      echo $(( done * 100 / total ))
    fi
  fi
}

get_lock_holder() {
  if [[ -f "$LOCK_FILE" ]]; then
    jq -r '.actor // ""' "$LOCK_FILE" 2>/dev/null || true
  fi
}

get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

get_iso_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

get_git_branch() {
  if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD
  fi
}

get_git_base_branch() {
  if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse >/dev/null 2>&1; then
    for b in main master; do
      if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$b"; then
        echo "$b"
        return
      fi
    done
  fi
}
