# orca plan

**Task:** the words after `plan`.

Produce a minimal, phased, approved plan. State lives in `.orca/workflows/current/`. Terms: `references/GLOSSARY.md`.

For every user choice or approval in this procedure, follow `references/human-input.md`: use Codex's `request_user_input` UI when available, and fall back to chat only when the tool is unavailable.

## Step 0 — Lock

Run `bash .orca/scripts/lock.sh planner`. If it exits non-zero, another live driver is active — stop, report the holder, and ask how to proceed.

## If a workflow already exists

Read `status.json` (task, status) and `Plan.md`. Ask the user through `references/human-input.md`: **continue planning** (extend/refine) or **start executing** (`$orca execute`). For continue: research the requested change, run the stress-test below for the changed portion, update `Implementation_Notes.md`/`Plan.md`/decisions as needed, run `bash .orca/scripts/parse-plan.sh`, re-present for approval. Then release the lock.

## If no workflow exists

### 1. Initialize

`bash .orca/scripts/init-workflow.sh "<task>"` — creates `status.json` (status `RESEARCH`), `Plan.md`, `Implementation_Notes.md`, `decisions.json`/`Decisions.md`, `Advisory_Notes.md`, and records the git branch.

### 2. Research (parallel subagents)

Dispatch research in parallel using Codex's native subagents — the user asking to plan authorizes this. Call `spawn_agent` once per research dimension, `wait` for all, then `close_agent` each:

- **Always:** a codebase explorer (use the `codebase-researcher` brief in `.orca/agents/codebase-researcher.md`) to map relevant files, patterns, and integration points.
- **If relevant:** read the `description` of each `.orca/agents/*.md` specialist; spawn the ones whose domain overlaps the task. Infer from descriptions — don't keyword-match.

Keep briefs short (each lane is a real model thread). For a tiny task, one explorer is enough.

### 3. Synthesize

Append findings to `Implementation_Notes.md` under `## Findings`, one subsection per source, each citing where it came from (`path:line`, doc URL, or lane name).

### 4. Stress-test

Before writing phases, run a short planning-pressure pass:

- Walk the design tree: goal/done-condition, scope edges, constraints, integration points, data/domain terms, verification, and failure cases.
- If code/docs can answer an unknown, inspect them instead of asking the user. Record the answer and source under `## Planning Pressure` in `Implementation_Notes.md`.
- If an unknown materially changes phase structure and cannot be discovered, ask exactly one sharp question at a time through `references/human-input.md` and include your recommended answer. Record the decision with `add-decision.sh`, then record the chosen answer before approval.
- If an unknown is safe to defer, turn it into an `[untested]` assumption and make the relevant phase pre-flight check it before edits.
- If the repo already has `CONTEXT.md`, `CONTEXT-MAP.md`, or `docs/adr/`, use those docs as planning inputs. If planning resolves a new domain term or an ADR-worthy trade-off, add an explicit phase step to update the existing docs. Do not introduce new glossary/ADR conventions unless the user asked.

### 5. Write the plan

Edit `Plan.md` directly — it is the source of truth for phase/step structure (`parse-plan.sh` derives `status.json.phases[]` from it).

Write an **Assumptions** block first. Surface every non-trivial premise; tag each `[verified]` (you checked code/docs/user) or `[untested]` (a guess the executor will check at phase start).

Then phases, in this strict format (the parser fails otherwise):

```markdown
### Phase 1: Phase Name

**Steps:**
1. First step (file: `path/to/file.ts`, action: create|modify)
2. Second step (file: `path/to/other.ts`, action: modify)

**Verify:**
- Manual: what to do, what to expect
- Auto: `optional-shell-command`
```

Rules:
- `### Phase N:` headings, numbered. Steps as a numbered list under `**Steps:**`. Every implementation step names its file(s) in backticks so `commit-phase.sh` can scope the commit.
- `**Verify:**` with `- Manual:` (required) and `- Auto:` (optional). For `Auto`, detect the project's tooling first (lockfile → package manager; read `scripts`/config for the real command name). If there's no usable script, omit the `Auto` line.
- No checkboxes (done lives in `status.json`), no new test scaffolding unless asked, no rollback/back-compat code by default, no assumed fallbacks (ask instead), no speculative abstractions. Every step traces to the request.

Then `bash .orca/scripts/parse-plan.sh` to rebuild `status.json.phases[]` (existing `done` flags are preserved by step ID).

If `update_plan` is available, refresh the display mirror from `references/native-tasks.md` so the approved phases appear as pending native tasks.

### 6. Decisions

For each ambiguous choice that survived the stress-test, `bash .orca/scripts/add-decision.sh add "Question" "Recommended answer"` (returns `D###`, re-renders `Decisions.md`). Resolve approval-blocking decisions through `references/human-input.md`, then record each answer with `bash .orca/scripts/add-decision.sh answer D001 "Chosen answer" user`. Never edit `Decisions.md` by hand.

### 7. User review

Present the plan summary, assumptions, and any pending decisions inline; link to `Plan.md` and `Decisions.md` as the durable records, but do not make the user open them to answer. Resolve approval-blocking decisions one at a time through `references/human-input.md`; record each answer immediately. Then request plan approval through `references/human-input.md`. **Wait for explicit approval.**

### 8. Validation pass

After approval, re-dispatch the same specialists (via `spawn_agent`) to review the plan: does it follow current docs/APIs? anti-patterns? gotchas? Each returns `APPROVED` or `CONCERNS` with specifics. On concerns: edit `Plan.md`, re-run `parse-plan.sh`, re-present.

### 9. Finalize

```
jq '.status = "PENDING" | .planApproved = true' .orca/workflows/current/status.json > /tmp/orca.status && mv /tmp/orca.status .orca/workflows/current/status.json
bash .orca/scripts/log-event.sh planner "Plan approved — ready for execution"
bash .orca/scripts/unlock.sh planner
```

Tell the user the next step: `$orca execute` to run phase-by-phase, `$orca execute-headless` to opt into app-managed recurring headless execution, or `bash .orca/scripts/phase-runner.sh` for a continuous CLI run.
