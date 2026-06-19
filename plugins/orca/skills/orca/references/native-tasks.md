# orca native task mirror

Mirror the active workflow into Codex's native task list using the `update_plan` tool when it is available. This is the same checklist surface Codex shows while working in the desktop app. It is a visibility layer only: `.orca/workflows/current/status.json` and `Plan.md` remain the source of truth.

## Rules

- Use `update_plan` when that tool is available. If it is not available, continue the workflow and rely on `.orca` state plus the normal report/Triage output.
- Each `update_plan` call sends the full current checklist, with each item using one of: `pending`, `in_progress`, or `completed`.
- Rebuild the mirror from disk (`status.json`, `Plan.md`, `Decisions.md`, `Advisory_Notes.md`) at the start of each command. Do not trust a stale checklist from memory.
- Keep at most one item `in_progress`.
- Update the mirror before starting a major action and immediately after completing it.
- Do not create checkboxes in `Plan.md`; native tasks are display-only and can be regenerated.
- When blocked, rename the active item to start with `BLOCKED:` and leave it `in_progress` so the UI shows where the workflow stopped.
- When waiting for the user, rename the active item to start with `Waiting:` and leave it `in_progress`.

## Planning mirror

After a plan is approved and `parse-plan.sh` has rebuilt `status.json.phases[]`, call `update_plan` with:

1. `Plan approved`
2. One pending item per phase: `P1: <phase name>`, `P2: <phase name>`, ...

If planning is still awaiting approval, call `update_plan` with the current planning stage as `in_progress` and future phases pending.

## Execution mirror

After selecting a phase for `execute`, `execute-headless`, or `resolve`, call `update_plan` with one checklist for that phase:

1. `P#: pre-flight`
2. One item per pending plan step: `P#.S#: <step summary>`
3. `P#: verify`
4. `P#: self-review`
5. `P#: external audit`
6. `P#: commit`
7. `P#: complete`

Mark already-done plan steps `completed` by reading `status.json.phases[].steps[].done`. When entering a step, mark it `in_progress`; after `mark-step-done.sh` succeeds, mark it `completed`.

For `resolve`, use the same mirror but start with:

1. `P#: load blockers`
2. One item per blocking finding from `Audit_Issues.md`
3. `P#: re-audit`
4. `P#: commit`
5. `P#: complete`

## Headless and automations

App automations should still use `update_plan` if the tool exists in that run. If it does not, the final one-line status and heartbeat/Triage output are the fallback visibility surface.
