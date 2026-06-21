---
name: orca
description: 'Codex workflow router for "$orca": plan tasks, execute audited phases, resolve blocks, revise plans, sync AGENTS.md, manage audit agents, prepare headless app execution, and archive .orca workflows. Use on "$orca", "/orca:", "orca <command>", or .orca workflow requests.'
---

# Orca

Orca runs a disciplined coding workflow on Codex: **research → plan → phase-by-phase execution → mandatory parallel subagent audit → resolve → archive**. The source of truth is always the target repo's `.orca/` directory. Never reconstruct workflow state from memory — read it.

Shared vocabulary (phase, step, lane, blocking/advisory, decision, the `status` enum) is defined in `references/GLOSSARY.md`. Read it once if any term is unclear.

## Is orca set up in this repo?

If `.orca/` does not exist, the repo isn't initialized. Read `references/app-setup.md` and run the installer, then continue.

## Routing

Parse the first word after `orca` (or after `/orca:`) as the command. Read the matching reference **completely** and follow it exactly. Pass the remaining words as that command's arguments.

| Command | Reference | What it does |
|---|---|---|
| `plan` | `references/plan.md` | Research + write a phased plan; log decisions. |
| `plan-advanced` | `references/plan-advanced.md` | Plan with a relentless interview pass first. |
| `execute` | `references/execute.md` | Run the next (or named) phase: implement → verify → audit → commit. |
| `execute-headless` | `references/execute-headless.md` | One-phase contract for automations and the CLI runner. |
| `audit` | `references/audit.md` | The mandatory parallel subagent audit (used by execute). |
| `resolve` | `references/resolve.md` | Fix a BLOCKED phase, then re-audit. |
| `revise` | `references/revise.md` | Change the plan mid-flight when reality diverges. |
| `docs-sync` | `references/docs-sync.md` | Update per-directory AGENTS.md from the implementation. |
| `agent` | `references/agent.md` | Create a project specialist in `.orca/agents/`. |
| `app-setup` | `references/app-setup.md` | Install orca into the repo + prepare desktop-app headless execution. |
| `archive` | `references/archive.md` | Move the finished workflow to `archived/`. |

- **Cleanup-only review:** use the separate `$simplify` skill (`$orca simplify` → just run `$simplify`). It is quality-only and never replaces the audit.
- **Update orca:** there is no orca command — upgrade natively with `codex plugin marketplace upgrade && codex plugin add orca@orca`. Workflows under `.orca/workflows/` are untouched.

## Invariants (hold for every command)

- **State on disk.** `.orca/workflows/current/status.json` is the single source of truth. Read it; don't guess. Mutate it only through `.orca/scripts/*.sh`, never by hand.
- **Native task visibility.** When Codex exposes `update_plan`, mirror current workflow progress there using `references/native-tasks.md`. It is display-only; `.orca` state wins.
- **Native user input.** When Codex exposes `request_user_input`, use it for approval-blocking choices and plan/revision approval (`references/human-input.md`). `decisions.json` is the record; chat is only the fallback prompt surface.
- **Headless automation lifecycle.** Desktop app Automations are opt-in: create or enable `orca execute` and `orca heartbeat` only from `$orca execute-headless`, and pause them when the workflow reaches `COMPLETED`.
- **One driver at a time.** Acquire the lock with `lock.sh <actor>` before changing a workflow; release with `unlock.sh <actor>`. If any live driver holds `.orca/workflows/current/.lock`, stop and report the holder.
- **Mandatory audit.** Every executed phase gets an independent review by parallel specialist subagents before it is committed (`references/audit.md`). Self-review never substitutes. The user invoking `execute` IS authorization to spawn subagents. If no subagent mechanism is available, BLOCK the phase — do not silently downgrade to self-review.
- **Scoped commits.** Commit only the files a phase touched, via `commit-phase.sh`. Never blanket-commit another actor's changes.
- **No autonomous decisions during execution.** On ambiguity, multiple valid approaches, or plan/reality divergence: stop and ask, or run `$orca revise`.
- **Minimal by default.** No speculative abstractions, fallbacks, rollback code, or "while we're at it" cleanup unless the user asked.

## Scripts

Mechanical, checkable steps are deterministic scripts under `.orca/scripts/` — run them with `bash .orca/scripts/<name>.sh`. The references name which script to run at each step. Detect the project's package manager/test runner before generating any `verify.auto` command; never hardcode `npm run`.
