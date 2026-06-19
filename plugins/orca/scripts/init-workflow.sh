#!/bin/bash
# Initialize a new workflow: status.json + Plan.md skeleton + decisions.json +
# Implementation_Notes.md + Advisory_Notes.md.
# Plan.md is the source of truth for phase/step structure; status.json tracks done/log/git.
# decisions.json is the canonical decision store; Decisions.md is rendered from it.
#
# Task names are arbitrary user text. JSON is built with jq, and markdown headers
# inject the task via `printf '%s'` (an argument is never evaluated) with the static
# body from a quoted heredoc — so backticks, $, &, %, quotes, etc. are all safe.

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

TASK_NAME="${1:-}"

if [[ -z "$TASK_NAME" ]]; then
  echo "ERROR: Task name required" >&2
  exit 1
fi

if workflow_exists; then
  echo "ERROR: Active workflow exists: $(get_task_name)" >&2
  echo "       Archive it (\$orca archive) or clear .orca/workflows/current/ first." >&2
  exit 1
fi

mkdir -p "$WORKFLOW_DIR"
TIMESTAMP=$(get_timestamp)
ISO_TS=$(get_iso_timestamp)
BRANCH=$(get_git_branch || true)
BASE_BRANCH=$(get_git_base_branch || true)

# status.json — built with jq so any task text (quotes, $, backticks, newlines) is safe.
jq -n --arg task "$TASK_NAME" --arg ts "$TIMESTAMP" --arg iso "$ISO_TS" \
      --arg branch "${BRANCH:-}" --arg base "${BASE_BRANCH:-}" '
  {
    task: $task,
    status: "RESEARCH",
    currentPhase: 0,
    totalPhases: 0,
    lastUpdated: $ts,
    createdAt: $iso,
    planApproved: false,
    phases: [],
    git: { branch: $branch, baseBranch: $base, phaseCommits: {} },
    log: [ { time: $ts, actor: "system", action: "Workflow initialized" } ]
  }
' > "$STATUS_FILE"

# decisions.json — also via jq.
jq -n --arg task "$TASK_NAME" '{ task: $task, decisions: [] }' > "$WORKFLOW_DIR/decisions.json"
bash "$SCRIPT_DIR/render-decisions.sh" >/dev/null

# Implementation_Notes.md
{
  printf '# Implementation Notes\n\n> Task: %s\n> Created: %s\n\n' "$TASK_NAME" "$TIMESTAMP"
  cat <<'EOF'
_Populated during research. Add sections as agents complete; structure is free-form._

## Findings
EOF
} > "$WORKFLOW_DIR/Implementation_Notes.md"

# Plan.md — the source of truth for phases and steps.
{
  printf '# Implementation Plan\n\n> Task: %s\n> Created: %s\n\n' "$TASK_NAME" "$TIMESTAMP"
  cat <<'PLAN_EOF'
## Overview

_Summary of implementation_

## Prerequisites

_What must exist first_

## Assumptions

<!--
List every non-trivial premise the plan rests on. Tag each:
  [verified]  — actually checked the codebase, docs, or user
  [untested]  — guessed; the executor will surface these at phase start
Assumptions are advisory; they don't block execution.
-->

- [untested] _Replace with real assumptions before approving the plan_

## Phases

<!--
Replace the placeholder phase before approving the plan. Keep the strict phase
format from the orca plan reference: numbered Phase headings, numbered Steps,
and a Verify block with Manual plus optional Auto.
-->

### Phase 1: [Name]

**Steps:**
1. Step description (file: `path/to/file.ts`, action: create|modify)

**Verify:**
- Manual: What to do, what to expect
- Auto: `optional-command`
PLAN_EOF
} > "$WORKFLOW_DIR/Plan.md"

# Advisory_Notes.md — growing memory of patterns to avoid.
{
  printf '# Advisory Notes\n\n> Task: %s\n\n' "$TASK_NAME"
  cat <<'EOF'
Patterns to avoid in future phases, accumulated from each phase's audit.
The executor reads this file at the start of every phase and treats every
entry as a "do not repeat" rule. Entries are appended; old entries are
never removed automatically — they remain as guardrails for the rest of the workflow.

## Patterns to avoid

_None yet — populated after the first phase audit._
EOF
} > "$WORKFLOW_DIR/Advisory_Notes.md"

echo "Workflow initialized: $TASK_NAME"
echo "  branch: ${BRANCH:-<not a git repo>}"
echo "  artifacts: $WORKFLOW_DIR"
