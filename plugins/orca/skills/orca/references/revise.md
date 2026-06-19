# orca revise

Change the plan mid-flight when reality diverges from it. Use this instead of silently improvising during execution. Terms: `references/GLOSSARY.md`.

## Step 0 — Lock

`bash .orca/scripts/lock.sh planner`. If non-zero, stop and report.

## Step 1 — Name the divergence

State plainly what's wrong with the current plan: a step that can't work as written, a missing phase, a wrong assumption surfaced at execution, or a decision that changed. Read `Plan.md`, `status.json`, and `Decisions.md` so the change is grounded.

## Step 2 — Edit the plan

Edit `Plan.md` directly, keeping the strict phase format (`references/plan.md`). Touch only what must change:
- New facts → update the **Assumptions** block (re-tag `[verified]`/`[untested]`).
- Changed choices → `bash .orca/scripts/add-decision.sh add "..." "..."` (and `answer` once decided); never edit `Decisions.md` by hand.
- Keep already-completed phases intact unless they must change; if a completed phase is invalidated, say so explicitly and confirm with the user before rewriting it.

## Step 3 — Reparse

`bash .orca/scripts/parse-plan.sh`. It rebuilds `status.json.phases[]` and **preserves `done` flags by step ID** — but reordering steps realigns flags by position, so check the result if you reordered.

## Step 4 — Re-present and unlock

Show the diff in the plan and any new/changed decisions. Get approval for material changes. Then `bash .orca/scripts/log-event.sh planner "Plan revised: <summary>"` and `bash .orca/scripts/unlock.sh planner`. Tell the user to resume with `$orca execute`.
