# orca archive

Move a finished (or abandoned) workflow out of `current/` so the repo is ready for the next one. Terms: `references/GLOSSARY.md`.

## Steps

1. Read `status.json`. If `status != COMPLETED`, confirm with the user that they really want to archive an unfinished workflow.
2. If a desktop-app worktree was used for this workflow, make sure its work is merged back first (review pane → push branch → PR, or Handoff to Local). Archiving only moves the `.orca/` state, not your git branches.
3. `bash .orca/scripts/archive-workflow.sh` — moves `.orca/workflows/current/` to `.orca/workflows/archived/<YYYY-MM-DD>-<task-slug>/`.
4. Report the archive path. The repo now has no active workflow; the next `$orca plan` starts clean.

Archived workflows are tracked in git (only `current/` is gitignored), so the plan, decisions, and audit history stay with the repo as a record.
