# orca human input

Use Codex's native `request_user_input` tool when it is available. This gives the user a real UI choice instead of asking them to inspect `Decisions.md` and reply in chat. If the tool is unavailable, fall back to a concise chat question.

## Rules

- Use `request_user_input` for approval-blocking decisions, plan approval, and material revision approval.
- Ask at most three questions per call; prefer one question for anything load-bearing.
- Each question must include 2-3 mutually exclusive choices. Put Orca's recommendation first and suffix the label with `(Recommended)`.
- Include a short `description` for each choice that states the tradeoff or impact.
- Do not use `autoResolutionMs` for approval-blocking decisions or plan approval. Wait for explicit input.
- If the user selects the free-form Other option, treat the entered text as the chosen answer.
- After every decision answer, immediately record it with `bash .orca/scripts/add-decision.sh answer <D###> "<chosen answer>" user`.
- `decisions.json` and rendered `Decisions.md` remain the durable record. The UI prompt is the interaction surface, not the source of truth.

## Decision Prompt Shape

For a pending decision:

- `header`: the decision id, such as `D001`
- `question`: the decision question, including enough context to answer without opening `Decisions.md`
- first option: the recommended answer from `decisions.json`
- second/third option: real alternatives when known, or a concise "Defer as assumption" option only when deferral is safe and the plan includes a pre-flight check

If there are no meaningful alternatives and the answer is effectively yes/no, ask for confirmation:

- `<recommended answer> (Recommended)`
- `Revise answer`

## Plan Approval Shape

After presenting the plan summary and assumptions, ask:

- `Approve plan (Recommended)` — mark the plan approved and continue to validation/finalization
- `Request changes` — keep planning open and collect the requested edits
- `Pause planning` — leave the workflow in `RESEARCH` and release the lock only after recording the pause

Do not finalize the plan unless the user explicitly chooses approval.

## Revision Approval Shape

For material plan revisions, ask:

- `Approve revision (Recommended)` — accept the revised `Plan.md` and decisions
- `Request changes` — keep the planner lock and edit again
- `Cancel revision` — leave the existing approved plan unchanged unless already edited; if files were edited, clearly state what must be reverted or re-run
