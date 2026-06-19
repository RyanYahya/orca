# orca plan-advanced

Same outcome as `plan`, but with a relentless interview pass **first** — for tasks where the requirements are fuzzy and a wrong premise would waste phases. Terms: `references/GLOSSARY.md`.

## Step 1 — Interview before planning

Interrogate the task until the plan would have no load-bearing unknowns. Ask one sharp question at a time; don't dump a checklist. Cover:

- **Goal & done-condition** — what does success look like, concretely and checkably?
- **Scope edges** — what is explicitly out of scope? what must NOT change?
- **Constraints** — APIs/versions/patterns to use or avoid; performance/security/compat requirements.
- **Unknowns** — every place you'd otherwise guess. Convert guesses into questions or into `[untested]` assumptions to verify during research.
- **Decisions** — surface real forks now; record each with `add-decision.sh`.

If the project has a dedicated interview/grilling skill available, you may invoke it for this pass instead of duplicating the questioning here.

Stop interviewing when you could write the Assumptions block with mostly `[verified]` items and no hidden forks.

## Step 2 — Plan

Now follow `references/plan.md` exactly (lock, init, research, synthesize, write plan, decisions, review, validation, finalize). Carry the interview answers into the Assumptions block and `decisions.json` so they're recorded, not just remembered.
