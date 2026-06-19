# orca docs-sync

**Scope (optional):** the words after `docs-sync` (a path or area). Omit for the whole change.

Bring Codex's instruction surface — the layered **AGENTS.md** files — back in sync with what the code now does. Codex reads `AGENTS.md` (global `~/.codex/AGENTS.md`, repo root, and nested per-directory), so docs that drift mislead every future run. Terms: `references/GLOSSARY.md`.

## Step 1 — Determine what changed

Use the workflow's phase commits (`status.json.git.phaseCommits`) or `git diff` against the base branch to find the touched areas. Group changed files by the directory whose `AGENTS.md` should describe them (root for cross-cutting; subdir for local).

## Step 2 — Update per directory (parallel)

For each affected directory, spawn a subagent (`spawn_agent`, in parallel; `wait`; `close_agent`) to update that directory's `AGENTS.md`:

- If `AGENTS.md` exists, reconcile it with the new reality — fix stale commands, paths, conventions, and architecture notes for that directory only.
- If it doesn't and the directory now warrants one (non-obvious setup, conventions, or gotchas), create a short one.
- Keep each `AGENTS.md` **lean and high-signal** — it's always-on context. State what's non-obvious and durable; don't restate what the code makes obvious. Don't touch `CLAUDE.md` (that's a different tool's surface).

## Step 3 — Report

List the `AGENTS.md` files created/updated and the key changes. These edits are part of the working tree — commit them with the relevant phase (or as a docs commit) per the user's preference; don't auto-commit outside a phase scope.
