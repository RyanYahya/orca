# orca plan-advanced

Same outcome as `plan`, but with a relentless interview pass **first** for tasks where the requirements are fuzzy and a wrong premise would waste phases. Terms: `references/GLOSSARY.md`.

## Step 1 — Interview before planning

Interrogate the task until the plan would have no load-bearing unknowns. Ask one sharp question at a time; don't dump a checklist. Cover:

- **Goal & done-condition** — what does success look like, concretely and checkably?
- **Scope edges** — what is explicitly out of scope? what must NOT change?
- **Constraints** — APIs/versions/patterns to use or avoid; performance/security/compat requirements.
- **Unknowns** — every place you'd otherwise guess. Convert guesses into questions or into `[untested]` assumptions to verify during research.
- **Decisions** — surface real forks now; keep the question and recommended answer in the interview notes, then record them with `add-decision.sh` after the workflow is initialized.
- **Domain/docs** — if the task introduces project-specific terms or durable trade-offs, check whether the repo already uses `CONTEXT.md`, `CONTEXT-MAP.md`, or `docs/adr/`; plan updates to those docs when they exist and the choice is worth preserving.

For every question, provide your recommended answer. If the answer can be found by exploring the codebase, explore instead of asking.

Stop interviewing when you could write the Assumptions block with mostly `[verified]` items and no hidden forks.

## Step 2 — Plan

Now follow `references/plan.md` exactly (lock, init, research, synthesize, stress-test, write plan, decisions, review, validation, finalize). Immediately after `init-workflow.sh` creates the workflow, append the interview notes under `## Planning Pressure` in `Implementation_Notes.md` and record each interview decision with `add-decision.sh`. Carry the interview answers into the Assumptions block and `decisions.json` so they're recorded, not just remembered. The normal stress-test still runs; use it as a check against the interview answers, not as a second long interview.
