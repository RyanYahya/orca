# Orca glossary

One vocabulary, used everywhere — in skills, references, scripts, status fields, and log actions. When a reference needs a term, it means exactly this. Prefer these words over the _Avoid_ synonyms so the agent and the human read the same map.

## Core nouns

- **workflow** — one tracked task, living in `.orca/workflows/current/`. Archived to `.orca/workflows/archived/<date>-<task>/` when done.
- **phase** — a numbered unit of work (`P1`, `P2`, …). Phases run **sequentially**; one is executed and audited at a time.
- **step** — a numbered action inside a phase (`P1.S1`). Carries a file reference: `` (file: `path`, action: create|modify) ``.
- **decision** — an open choice recorded in `decisions.json` (`D001`, …) and rendered to `Decisions.md`. Resolved by the user.
- **lane** — one specialist auditor in the post-phase audit (e.g. `code-auditor`). Each lane = one read-only subagent.
- **actor** — who holds the lock: `planner`, `executor`, `auditor`, `phase-runner`, or `automation`.
- **native task mirror** — Codex's native task list shown through `update_plan`, displaying the current workflow or phase. Display-only; regenerated from `.orca` state and never authoritative.

## The audit verdict

- **blocking** — an issue that must be fixed before the phase is committed. Any blocking finding ⇒ the phase is **BLOCKED**.
- **advisory** — a non-blocking suggestion (simplicity, trace, surgical scope). Recorded or auto-fixed, but never changes the verdict.
- **APPROVED / ISSUES** — a lane's verdict. `APPROVED` only when its `blocking` list is empty.

## status.json `status` enum

`RESEARCH` → planning underway · `PENDING` → plan approved, phases remain · `BLOCKED` → an audit found blocking issues; stop and resolve · `COMPLETED` → every phase done.

## State files (in `.orca/workflows/current/`)

- **status.json** — the single source of truth for execution state (task, status, `phases[]`, `git`, `log[]`). Mutated only by scripts.
- **Plan.md** — the source of truth for phase/step **structure**. `parse-plan.sh` derives `status.json.phases[]` from it.
- **Implementation_Notes.md** — research findings and planning-pressure notes.
- **decisions.json** / **Decisions.md** — canonical decisions / rendered view.
- **Advisory_Notes.md** — cumulative "patterns to avoid", appended after each audit; read at the start of every phase.
- **Audit_Issues.md** — written only when a phase is BLOCKED.
- **.lock** — single-actor lock.

## _Avoid_ (synonyms that drift — don't use these)

task→**workflow** · stage/milestone→**phase** · subtask/todo→**step** · reviewer/critic→**lane** · bug/finding(when it stops a phase)→**blocking** · nit/suggestion→**advisory** · question/issue(for a choice)→**decision**.
