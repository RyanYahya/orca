#!/bin/bash
# Commit work for a completed phase and record the SHA in status.json.
# Usage:
#   bash .orca/scripts/commit-phase.sh <phase-id> [--paths-from-plan|--paths-file <file>|--all] [extra message]
#
# Default mode is --paths-from-plan. It stages only files named in the phase
# steps, allows unrelated unstaged user changes to remain untouched, and refuses
# to commit if unrelated changes are already staged.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

usage() {
  cat >&2 <<'EOF'
usage: commit-phase.sh <phase-id> [--paths-from-plan|--paths-file <file>|--all] [extra message]

  --paths-from-plan   Stage only files referenced in the phase steps. Default.
  --paths-file FILE   Stage only newline-delimited paths from FILE.
  --all               Explicitly stage all changes with git add -A.

The scoped modes leave unrelated unstaged changes alone and refuse when
unrelated paths are already staged, so phase commits cannot accidentally absorb
another actor's work.
EOF
}

PHASE_ID="${1:-}"
[[ -n "$PHASE_ID" ]] || { usage; exit 1; }
shift || true

MODE="paths-from-plan"
PATHS_FILE=""
EXTRA_PARTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --paths-from-plan)
      MODE="paths-from-plan"; shift ;;
    --paths-file)
      MODE="paths-file"; PATHS_FILE="${2:-}"; [[ -n "$PATHS_FILE" ]] || { echo "ERROR: --paths-file requires a file" >&2; exit 1; }; shift 2 ;;
    --all)
      MODE="all"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    --)
      shift; EXTRA_PARTS+=("$@"); break ;;
    *)
      EXTRA_PARTS+=("$1"); shift ;;
  esac
done

EXTRA_MSG="${EXTRA_PARTS[*]:-}"

workflow_exists || { echo "ERROR: no active workflow" >&2; exit 1; }
jq -e --arg id "$PHASE_ID" 'any(.phases[]?; .id == $id)' "$STATUS_FILE" >/dev/null || { echo "ERROR: phase $PHASE_ID not found in status.json" >&2; exit 1; }

AUDIT_STATUS=$(jq -r --arg id "$PHASE_ID" '.phases[] | select(.id == $id) | .audit.status // ""' "$STATUS_FILE")
if [[ "$AUDIT_STATUS" != "APPROVED" ]]; then
  echo "ERROR: phase $PHASE_ID audit is not APPROVED; run the mandatory audit before committing" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1 || ! git -C "$PROJECT_ROOT" rev-parse >/dev/null 2>&1; then
  echo "warn: not a git repo; skipping commit" >&2
  exit 0
fi

cd "$PROJECT_ROOT"

PHASE_NAME=$(jq -r --arg id "$PHASE_ID" '.phases[] | select(.id == $id) | .name' "$STATUS_FILE")
[[ -n "$PHASE_NAME" && "$PHASE_NAME" != "null" ]] || { echo "ERROR: phase $PHASE_ID not found in status.json" >&2; exit 1; }

TASK=$(get_task_name)

normalize_path() {
  local p="$1"
  p="${p#./}"
  p="${p%/}"
  printf '%s\n' "$p"
}

extract_paths_from_plan() {
  jq -r --arg id "$PHASE_ID" '.phases[] | select(.id == $id) | .steps[].text' "$STATUS_FILE" \
    | awk '
      {
        line = $0
        while (match(line, /`[^`]+`/)) {
          token = substr(line, RSTART + 1, RLENGTH - 2)
          if (token ~ /^[A-Za-z0-9_@.+\/-]+$/ && (token ~ /\// || token ~ /\./)) print token
          line = substr(line, RSTART + RLENGTH)
        }
      }
    ' \
    | sed 's#^\./##; s#/$##' \
    | awk 'NF && !seen[$0]++'
}

load_allowed_paths() {
  case "$MODE" in
    paths-from-plan)
      extract_paths_from_plan ;;
    paths-file)
      [[ -f "$PATHS_FILE" ]] || { echo "ERROR: paths file not found: $PATHS_FILE" >&2; exit 1; }
      sed 's#^\./##; s#/$##' "$PATHS_FILE" | awk 'NF && !seen[$0]++' ;;
    all)
      return 0 ;;
    *)
      echo "ERROR: unknown commit mode: $MODE" >&2; exit 1 ;;
  esac
}

path_is_allowed() {
  local path="$1" allowed
  for allowed in "${ALLOWED_PATHS[@]}"; do
    [[ -n "$allowed" ]] || continue
    if [[ "$path" == "$allowed" || "$path" == "$allowed/"* ]]; then
      return 0
    fi
  done
  return 1
}

status_path() {
  local line="$1" path
  path="${line:3}"
  if [[ "$path" == *" -> "* ]]; then
    path="${path##* -> }"
  fi
  path="${path#\"}"
  path="${path%\"}"
  normalize_path "$path"
}

if [[ "$MODE" == "all" ]]; then
  git add -A
else
  ALLOWED_PATHS=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && ALLOWED_PATHS+=("$p")
  done < <(load_allowed_paths)

  if [[ "${#ALLOWED_PATHS[@]}" -eq 0 ]]; then
    cat >&2 <<EOF
ERROR: no phase file paths found for $PHASE_ID.
Add \`(file: \`path/to/file\`, action: modify)\` to the phase steps, pass --paths-file <file>, or use --all explicitly.
EOF
    exit 1
  fi

  STAGE_PATHS=()
  OUTSIDE_STAGED=()
  OUTSIDE_UNSTAGED=()

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    xy="${line:0:2}"
    x="${xy:0:1}"
    y="${xy:1:1}"
    path="$(status_path "$line")"

    if path_is_allowed "$path"; then
      STAGE_PATHS+=("$path")
    elif [[ "$x" != " " && "$x" != "?" ]]; then
      OUTSIDE_STAGED+=("$path")
    elif [[ "$y" != " " || "$x" == "?" ]]; then
      OUTSIDE_UNSTAGED+=("$path")
    fi
  done < <(git status --porcelain=v1 --untracked-files=all)

  if [[ "${#OUTSIDE_STAGED[@]}" -gt 0 ]]; then
    echo "ERROR: unrelated staged changes exist outside $PHASE_ID scope:" >&2
    printf '  %s\n' "${OUTSIDE_STAGED[@]}" >&2
    echo "Unstage those paths or pass an explicit --paths-file that includes them if they belong to this phase." >&2
    exit 1
  fi

  if [[ "${#OUTSIDE_UNSTAGED[@]}" -gt 0 ]]; then
    echo "warn: leaving unrelated unstaged changes untouched:" >&2
    printf '  %s\n' "${OUTSIDE_UNSTAGED[@]}" >&2
  fi

  if [[ "${#STAGE_PATHS[@]}" -eq 0 ]]; then
    echo "no scoped changes for $PHASE_ID; skipping commit"
    exit 0
  fi

  git add -A -- "${STAGE_PATHS[@]}"

  STAGED_OUTSIDE=()
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    path="$(normalize_path "$path")"
    path_is_allowed "$path" || STAGED_OUTSIDE+=("$path")
  done < <(git diff --cached --name-only)

  if [[ "${#STAGED_OUTSIDE[@]}" -gt 0 ]]; then
    echo "ERROR: staged changes outside $PHASE_ID scope would be committed:" >&2
    printf '  %s\n' "${STAGED_OUTSIDE[@]}" >&2
    echo "Unstage those paths before retrying." >&2
    exit 1
  fi
fi

if git diff --cached --quiet; then
  echo "no staged changes for $PHASE_ID; skipping commit"
  exit 0
fi

MSG="orca($PHASE_ID): $PHASE_NAME"
if [[ -n "$EXTRA_MSG" ]]; then
  MSG="$MSG

$EXTRA_MSG"
fi
MSG="$MSG

Workflow: $TASK
Phase: $PHASE_ID - $PHASE_NAME"

git commit -m "$MSG" >/dev/null
SHA=$(git rev-parse HEAD)

jq --arg id "$PHASE_ID" --arg sha "$SHA" --arg ts "$(get_timestamp)" '
  .git = (.git // {})
  | .git.phaseCommits = (.git.phaseCommits // {})
  | .git.phaseCommits[$id] = $sha
  | .lastUpdated = $ts
  | .log += [{"time": $ts, "actor": "git", "action": "commit \($sha[0:7]) for \($id)"}]
' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

echo "committed $SHA for $PHASE_ID"
