# orca resolve

Clear a **BLOCKED** workflow: address the audit's blocking findings, then re-audit. Terms: `references/GLOSSARY.md`.

## Step 0 — Lock

`bash .orca/scripts/lock.sh executor`. If non-zero, stop and report the holder.

## Step 1 — Load the blockers

Confirm `status.json.status == BLOCKED`. Read `Audit_Issues.md` (the consolidated blocking findings), the failing phase's `audit` entry in `status.json`, and `references/native-tasks.md`. In the desktop app, also read any inline comments the human left in the Review pane — treat them as part of the resolve input. If `update_plan` is available, publish the resolve mirror from `references/native-tasks.md`.

## Step 2 — Fix

Address each blocking item. Mark the corresponding native task `in_progress` before fixing and `completed` after fixing, if available. Stay within the phase's scope (its `file:` paths). On genuine ambiguity or if a fix needs scope/plan changes, stop and ask, or run `$orca revise` — do not improvise a redesign. Make cheap advisory fixes too while you're here.

## Step 3 — Re-audit

Mark `P#: re-audit` `in_progress` in the native task mirror if available.

Re-run `references/audit.md` for this phase, with the **same lanes** that failed plus `code-auditor`. Pass the lanes the new diff and a note of what you changed.

- Still **ISSUES** → update `Audit_Issues.md`, leave `status` BLOCKED, rename the active native task to `BLOCKED: P#: re-audit` if available, report what's outstanding, unlock, stop.
- **APPROVED** → mark re-audit `completed` if available, clear the block, and continue:

```
jq '.status = "PENDING"' .orca/workflows/current/status.json > /tmp/orca.status && mv /tmp/orca.status .orca/workflows/current/status.json
bash .orca/scripts/record-audit.sh <id> --approved
rm -f .orca/workflows/current/Audit_Issues.md
```

## Step 4 — Commit, complete, continue

Mark `P#: commit` `in_progress` if available; `bash .orca/scripts/commit-phase.sh <id> --paths-from-plan`; mark commit `completed` if available; mark `P#: complete` `in_progress` if available; `bash .orca/scripts/complete-phase.sh <id>`; mark complete `completed` if available; then `bash .orca/scripts/unlock.sh executor`. Tell the user the workflow is unblocked and the next step (`$orca execute`, the Automation, or the phase-runner will resume on the next tick).
