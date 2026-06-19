#!/bin/bash
# Select audit specialist lanes from .orca/audit-map.json.
# Usage: select-audit-agents.sh <phase-id> [changed-file ...]
# Prints one specialist name per line (deduped, existence-checked against
# .orca/agents/<name>.md). Empty output means the caller should infer lanes.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

PHASE_ID="${1:-}"
[[ -n "$PHASE_ID" ]] || { echo "usage: select-audit-agents.sh <phase-id> [changed-file ...]" >&2; exit 1; }
shift || true

MAP_FILE="$PROJECT_ROOT/.orca/audit-map.json"
[[ -f "$MAP_FILE" ]] || exit 0
jq empty "$MAP_FILE" >/dev/null || { echo "ERROR: invalid audit map: $MAP_FILE" >&2; exit 1; }

AGENTS=()

agent_exists() {
  local name="$1"
  [[ -f "$PROJECT_ROOT/.orca/agents/$name.md" ]]
}

add_agent() {
  local name="$1" existing
  [[ -n "$name" && "$name" != "null" ]] || return 0
  agent_exists "$name" || return 0
  if [[ "${#AGENTS[@]}" -gt 0 ]]; then
    for existing in "${AGENTS[@]}"; do
      [[ "$existing" == "$name" ]] && return 0
    done
  fi
  AGENTS+=("$name")
}

decode_base64() {
  local value="$1"
  printf '%s' "$value" | base64 --decode 2>/dev/null || printf '%s' "$value" | base64 -D
}

while IFS= read -r agent; do add_agent "$agent"; done < <(jq -r --arg pid "$PHASE_ID" '.phases[$pid][]?' "$MAP_FILE")

while IFS= read -r rule; do
  matched=0
  while IFS= read -r pattern; do
    [[ -n "$pattern" && "$pattern" != "null" ]] || continue
    for changed in "$@"; do
      if [[ "$changed" == $pattern ]]; then
        matched=1
        break
      fi
    done
    [[ "$matched" -eq 1 ]] && break
  done < <(decode_base64 "$rule" | jq -r '(.paths // .match // [])[]?')

  if [[ "$matched" -eq 1 ]]; then
    while IFS= read -r agent; do add_agent "$agent"; done < <(decode_base64 "$rule" | jq -r '.agents[]?')
  fi
done < <(jq -r '.rules[]? | @base64' "$MAP_FILE")

while IFS= read -r agent; do add_agent "$agent"; done < <(jq -r '(.defaultAgents // .default // [])[]?' "$MAP_FILE")

# Guard the expansion: under `set -u`, "${AGENTS[@]}" on an empty array aborts on
# bash 3.2 (macOS default). Empty output is the documented "infer lanes" signal.
if [[ "${#AGENTS[@]}" -gt 0 ]]; then
  printf '%s\n' "${AGENTS[@]}"
fi
