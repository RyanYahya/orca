# orca execute-headless

The one-phase, no-human contract used by the desktop-app **execute Automation** and the **CLI phase-runner**. Advance exactly ONE pending phase, run the mandatory audit, then stop. Same `.orca/` state as interactive `execute`; the only difference is there's no one to ask, so anything that would prompt a human instead BLOCKS. Terms: `references/GLOSSARY.md`.

## Contract

1. **Read `status.json`.**
   - `status == COMPLETED` → do nothing; report "workflow complete"; stop.
   - `status == BLOCKED` → do nothing; report "blocked — see Audit_Issues.md; run `$orca resolve`"; stop.
   - `planApproved == false` → do nothing; report "plan not approved; run `$orca plan`"; stop.

2. **Lock.** `bash .orca/scripts/lock.sh <actor>` where `<actor>` is `phase-runner` (CLI) or `automation` (app). If non-zero, another live driver holds the lock — report it and stop (do not take over).

3. **Pick the phase** — the first in `status.json.phases[]` whose `status` is not `completed`.

4. **Pre-flight.** Verify `[untested]` assumptions for this phase by cheap checks. If one is false, you cannot ask a human: write the problem to `Audit_Issues.md`, `bash .orca/scripts/record-audit.sh <id> --issues --issues-file .orca/workflows/current/Audit_Issues.md` (sets BLOCKED), unlock, stop. Load `Advisory_Notes.md` as "do not repeat" rules.

5. **Execute the steps** one at a time, `mark-step-done.sh` after each. No autonomous scope changes — if the plan is wrong, BLOCK (as in step 4) rather than improvise.

6. **Verify.** Run `verify.auto` if set; on failure, BLOCK and stop. Manual verify can't run headless — record it skipped: `bash .orca/scripts/record-verify.sh <id> --auto PASS|FAIL|SKIP --manual SKIP`. (The human reviews later in the app Review pane / Triage.)

7. **Audit — MANDATORY.** Run `references/audit.md`. Prefer the **deterministic variant** (`codex exec -p orca-audit --json --output-schema .orca/audit.schema.json -o ...`) so the verdict is parseable. Any blocking ⇒ it sets BLOCKED; unlock and stop. All approved ⇒ continue.

8. **Commit + complete.** `bash .orca/scripts/commit-phase.sh <id> --paths-from-plan` then `bash .orca/scripts/complete-phase.sh <id>`. Both scripts enforce that the phase audit is recorded as `APPROVED`.

9. **Unlock + report.** `bash .orca/scripts/unlock.sh <actor>`. Print one terminal line: phase id, APPROVED/BLOCKED/COMPLETED, and progress %.

## Why one phase per run

`complete-phase.sh` advances `currentPhase` and sets `COMPLETED` (when no phase remains) or `PENDING`; `BLOCKED` is set only by the audit (`record-audit.sh --issues`). Each invocation re-reads `status.json`, so the *driver* (a cron Automation tick, or the phase-runner loop) becomes the loop — and runs naturally no-op once the workflow is COMPLETED or BLOCKED. Do not loop multiple phases inside one invocation. Do not `kill` any parent process; finish with the status line so `codex exec` exits 0.
