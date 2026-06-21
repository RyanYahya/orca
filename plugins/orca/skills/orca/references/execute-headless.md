# orca execute-headless

The one-phase, no-human contract used by the desktop-app **execute Automation** and the **CLI phase-runner**. Advance exactly ONE pending phase, run the mandatory audit, then stop. Same `.orca/` state as interactive `execute`; the only difference is there's no one to ask, so anything that would prompt a human instead BLOCKS. Terms: `references/GLOSSARY.md`.

When running in the Codex app, follow `references/automation-lifecycle.md`: `$orca execute-headless` is the opt-in point that creates or enables the execute + heartbeat Automations, and completion pauses them.

## Contract

0. **Automation lifecycle.** In the Codex app, if `automation_update` is available, update or create `orca execute` and `orca heartbeat` from `references/automation-lifecycle.md` with status `ACTIVE`, unless the workflow is already `COMPLETED`. If `automation_update` is unavailable, continue the one-phase run without app Automation changes; mention this only when the user expected app Automations to be created. In the CLI phase-runner, skip app Automation management entirely.

1. **Read `status.json`.**
   - `status == COMPLETED` → pause `orca execute` and `orca heartbeat` if `automation_update` is available; report "workflow complete"; stop.
   - `status == BLOCKED` → pause `orca execute` if `automation_update` is available; report "blocked — see Audit_Issues.md; run `$orca resolve`"; stop.
   - `planApproved == false` → do nothing; report "plan not approved; run `$orca plan`"; stop.

2. **Lock.** `bash .orca/scripts/lock.sh <actor>` where `<actor>` is `phase-runner` (CLI) or `automation` (app). If non-zero, another live driver holds the lock — report it and stop (do not take over).

3. **Pick the phase** — the first in `status.json.phases[]` whose `status` is not `completed`. If `update_plan` is available, publish the phase execution mirror from `references/native-tasks.md`.

4. **Pre-flight.** Mark `P#: pre-flight` `in_progress` in the native task mirror if available. Verify `[untested]` assumptions for this phase by cheap checks. If one is false, you cannot ask a human: write the problem to `Audit_Issues.md`, `bash .orca/scripts/record-audit.sh <id> --issues --issues-file .orca/workflows/current/Audit_Issues.md` (sets BLOCKED), rename the native task to `BLOCKED: P#: pre-flight` if available, unlock, stop. Load `Advisory_Notes.md` as "do not repeat" rules. Mark pre-flight `completed` if available.

5. **Execute the steps** one at a time. Mark each native step `in_progress` before starting and `completed` after `mark-step-done.sh` succeeds, if available. No autonomous scope changes — if the plan is wrong, BLOCK (as in step 4) rather than improvise.

6. **Verify.** Mark `P#: verify` `in_progress` in the native task mirror if available. Run `verify.auto` if set; on failure, BLOCK and stop. Manual verify can't run headless — record it skipped: `bash .orca/scripts/record-verify.sh <id> --auto PASS|FAIL|SKIP --manual SKIP`. (The human reviews later in the app Review pane / Triage.) Mark verify `completed` if available.

7. **Audit — MANDATORY.** Mark `P#: external audit` `in_progress` in the native task mirror if available. Run `references/audit.md`. Prefer the **deterministic variant** (`codex exec -p orca-audit --json --output-schema .orca/audit.schema.json -o ...`) so the verdict is parseable. Any blocking ⇒ it sets BLOCKED; rename the native task to `BLOCKED: P#: external audit` if available, unlock and stop. All approved ⇒ mark audit `completed` if available and continue.

8. **Commit + complete.** Mark `P#: commit` `in_progress` if available; `bash .orca/scripts/commit-phase.sh <id> --paths-from-plan`; mark commit `completed` if available; mark `P#: complete` `in_progress` if available; `bash .orca/scripts/complete-phase.sh <id>`; mark complete `completed` if available. Both scripts enforce that the phase audit is recorded as `APPROVED`. Re-read `status.json`; if it is now `COMPLETED`, pause `orca execute` and `orca heartbeat` through `automation_update` if available.

9. **Unlock + report.** `bash .orca/scripts/unlock.sh <actor>`. Print one terminal line: phase id, APPROVED/BLOCKED/COMPLETED, and progress %.

## Why one phase per run

`complete-phase.sh` advances `currentPhase` and sets `COMPLETED` (when no phase remains) or `PENDING`; `BLOCKED` is set only by the audit (`record-audit.sh --issues`). Each invocation re-reads `status.json`, so the *driver* (a cron Automation tick, or the phase-runner loop) becomes the loop. Do not loop multiple phases inside one invocation. Do not `kill` any parent process; finish with the status line so `codex exec` exits 0. In the app, completed workflows pause their recurring Automations instead of leaving them to no-op forever.
