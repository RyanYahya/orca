# orca execute

**Phase (optional):** the words after `execute` (e.g. `P3`). Omit to run the next pending phase.

Execute ONE phase end-to-end: pre-flight → steps → verify → audit → commit → complete. State: `.orca/workflows/current/`. Terms: `references/GLOSSARY.md`.

## Step 0 — Lock

`bash .orca/scripts/lock.sh executor`. If non-zero, another driver is active — stop and report.

## No autonomous decisions

Your role is to EXECUTE the plan, not reinterpret it. STOP and ask (or run `$orca revise`) on: ambiguity, multiple valid approaches, unexpected errors/edge cases not in the plan, plan/reality divergence, unclear locations, or trade-offs. When in doubt, ask.

If there's no active workflow (`status.json` missing) tell the user to `$orca plan <task>` first, release the lock, and stop. If `planApproved` is false, stop and finish planning.

## Step 1 — Load context

Read `status.json` (phases, progress, git), `Plan.md` (source of truth for steps), `Implementation_Notes.md`, `Decisions.md`, `Advisory_Notes.md`.

## Step 2 — Identify the phase

If an argument like `P3` was given, use it. Otherwise pick the first phase in `status.json.phases[]` whose `status` is not `completed`. Present its id, name, steps (with done flags), files, and verify block. Ask: "Ready to execute Phase \<id\>?"

## Step 3 — Pre-flight

Before writing code, sharpen the mental model:

1. **Assumptions** (from `Plan.md`): for each `[untested]` item do a cheap check (read a file, grep a symbol). Upgrade to `[verified]` if it holds; if it doesn't, **stop and ask** — the phase rests on a false premise.
2. **Decisions** (`Decisions.md`): internalize answers; don't re-litigate.
3. **Advisory_Notes.md**: treat every entry as a "do not repeat" rule for this phase.

Dirty-worktree policy: `git status --short` first; never stash/reset/reformat unrelated changes; if a file you must edit has unrelated user changes, pause and ask. The phase's listed `file:` paths are the commit scope.

State briefly which assumptions you checked and which advisory patterns you'll watch for, then `bash .orca/scripts/log-event.sh executor "Phase <id> pre-flight: <summary>"`.

## Step 4 — Execute steps, one at a time

For each pending step: **announce** → **implement** → `bash .orca/scripts/mark-step-done.sh <PID> <PID.SID>` → **show your work**. If a step is materially larger/riskier than the plan implied, pause and confirm. If a step says to run simplify, run the `$simplify` skill over this phase's diff (cleanup-only; it does **not** replace the audit).

## Step 5 — Verify

- **Auto:** read `verify.auto` for this phase (`jq -r --arg pid "<id>" '.phases[]|select(.id==$pid).verify.auto' .orca/workflows/current/status.json`). If non-empty, run it; capture exit code + last ~50 lines. On failure, stop and ask.
- **Manual:** present `verify.manual` to the user. In the desktop app, the human checks the diff in the **Review pane** (stage/revert per hunk, inline comments). Wait for their report.

Record: `bash .orca/scripts/record-verify.sh <id> --auto PASS|FAIL|SKIP --manual PASS|FAIL|SKIP`.

## Step 6 — Self-review, then the mandatory audit

**6a. Self-review** your own diff (`git diff HEAD`, or against the prior phase commit in `status.json.git.phaseCommits`) against: **simplicity** (anything beyond the steps?), **trace** (every line maps to a step? files outside scope?), **surgical** (drive-by edits?), **patterns** (anything from `Advisory_Notes.md` you just repeated?). Cheap fixes (delete an unused import/comment/abstraction you added, revert a stray format) → fix silently now. Material changes → surface to the user. Recurring pattern → append to `Advisory_Notes.md`.

**6b. External audit — MANDATORY.** Run the audit procedure in `references/audit.md` now. It spawns parallel specialist subagents, collects their verdicts, and either records APPROVED or sets the workflow BLOCKED. Self-review does **not** substitute. Do not continue to Step 7 until the audit recorded `APPROVED`.

## Step 7 — Commit the phase

`bash .orca/scripts/commit-phase.sh <id> --paths-from-plan` — refuses unless this phase has recorded audit `APPROVED`, stages only files named in the phase steps, refuses if unrelated changes are staged, commits `orca(<id>): <name>`, records the SHA. No-ops outside a git repo after the audit guard passes. (In the desktop app you can also review/push this commit from the Review pane.)

## Step 8 — Complete

`bash .orca/scripts/complete-phase.sh <id>` — refuses unless this phase has recorded audit `APPROVED`, marks it completed, advances `currentPhase`, flips status to `COMPLETED` when none remain else `PENDING`.

## Step 9 — Next or done

More phases remain → ask "Ready for Phase \<next\>?"; yes → return to Step 2; no → `bash .orca/scripts/unlock.sh executor` and pause. All complete → `bash .orca/scripts/unlock.sh executor`, present a final summary, and offer `$orca archive`.
