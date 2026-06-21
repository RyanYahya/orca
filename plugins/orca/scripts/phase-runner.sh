#!/bin/bash
# orca phase-runner — autonomous CLI executor for Codex.
#
# Loops `codex exec`, one orca phase per iteration (each runs the mandatory
# subagent audit), and stops at COMPLETED or BLOCKED. This is the escape hatch
# for continuous / headless / CI runs and machines the desktop app can't keep
# awake; the app's Automations cover scheduled, machine-on execution. Both share
# the identical .orca/ state and the execute-headless contract.
#
# Each child locks the workflow as actor "phase-runner" and unlocks when its
# phase finishes, so the runner never deadlocks an app automation — if another
# actor holds the lock, the child reports it and the runner stops.
#
# Usage:
#   bash .orca/scripts/phase-runner.sh                # auto, up to 20 phases
#   bash .orca/scripts/phase-runner.sh --manual       # pause between phases
#   bash .orca/scripts/phase-runner.sh 10             # cap at 10 phases
#
# Env:
#   ORCA_PROFILE       profile layered via `codex exec -p` (default: orca-exec, if installed)
#   ORCA_CODEX_FLAGS   extra flags for codex exec (e.g. --dangerously-bypass-approvals-and-sandbox in CI)
#   ORCA_LOG_FILE      run log (default: /tmp/orca-phase-runner.log)

set -euo pipefail

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/workflow-utils.sh"

MODE="auto"
MAX_PHASES=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manual) MODE="manual"; shift ;;
    --auto)   MODE="auto"; shift ;;
    [0-9]*)   MAX_PHASES="$1"; shift ;;
    -h|--help) echo "usage: phase-runner.sh [--manual|--auto] [max-phases]"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v codex >/dev/null 2>&1 || { echo "ERROR: 'codex' CLI not found in PATH" >&2; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "ERROR: 'jq' not found in PATH" >&2; exit 1; }
workflow_exists || { echo "ERROR: no active workflow. Run \$orca plan first." >&2; exit 1; }

PROFILE="${ORCA_PROFILE:-orca-exec}"
PROFILE_FILE="${CODEX_HOME:-$HOME/.codex}/$PROFILE.config.toml"
PROFILE_ARGS=()
[[ -f "$PROFILE_FILE" ]] && PROFILE_ARGS=(-p "$PROFILE")
read -r -a EXTRA_FLAGS <<< "${ORCA_CODEX_FLAGS:-}"
LOG_FILE="${ORCA_LOG_FILE:-/tmp/orca-phase-runner.log}"
NOTIFY="$SCRIPT_DIR/notify.sh"

PROMPT='Use the $orca skill and follow references/execute-headless.md exactly in CLI phase-runner mode. Advance exactly ONE pending phase of the active .orca workflow, run the mandatory subagent audit, then stop. Do not create or update Codex app Automations from this CLI run. If status.json status is COMPLETED or BLOCKED, report it and stop.'

log(){ echo "[$(get_timestamp)] $1" | tee -a "$LOG_FILE"; }

log "phase-runner start — task: $(get_task_name) — mode: $MODE — max: $MAX_PHASES"

for (( i=1; i<=MAX_PHASES; i++ )); do
  STATUS="$(get_status)"
  case "$STATUS" in
    COMPLETED)
      log "workflow COMPLETED ($(get_progress)%)"
      [[ -x "$NOTIFY" ]] && bash "$NOTIFY" "orca: workflow complete — $(get_task_name)" || true
      break ;;
    BLOCKED)
      log "workflow BLOCKED — see .orca/workflows/current/Audit_Issues.md; run \$orca resolve"
      [[ -x "$NOTIFY" ]] && bash "$NOTIFY" "orca: BLOCKED — $(get_task_name)" || true
      break ;;
  esac

  BEFORE="$(get_current_phase)"
  log "--- iteration $i (currentPhase=$BEFORE, progress $(get_progress)%) — launching codex exec ---"

  RC=0
  # `${arr[@]+"${arr[@]}"}` keeps empty arrays safe under `set -u` on bash 3.2 (macOS).
  codex exec "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}" --cd "$PROJECT_ROOT" "$PROMPT" >>"$LOG_FILE" 2>&1 || RC=$?
  log "codex exec exited $RC"

  if [[ "$RC" -ne 0 ]]; then
    log "non-zero exit; stopping for inspection. Tail: $LOG_FILE"
    exit "$RC"
  fi

  AFTER="$(get_current_phase)"
  NEW_STATUS="$(get_status)"
  if [[ "$NEW_STATUS" != "BLOCKED" && "$NEW_STATUS" != "COMPLETED" && "$AFTER" == "$BEFORE" ]]; then
    log "no phase progress this iteration (currentPhase still $AFTER) — stopping to avoid a spin loop."
    [[ -x "$NOTIFY" ]] && bash "$NOTIFY" "orca: stalled — $(get_task_name)" || true
    exit 1
  fi

  if [[ "$MODE" == "manual" ]]; then
    echo "Phase done (progress $(get_progress)%). Press ENTER for the next phase, Ctrl+C to stop."
    read -r
  else
    sleep 2
  fi
done

log "phase-runner finished — status: $(get_status) ($(get_progress)%)"
