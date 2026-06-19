# Orca 🐋

**A disciplined coding workflow for OpenAI Codex: plan → phased execution → a mandatory parallel subagent audit → resolve → archive.**

Orca is a Codex-native successor to [orchestra](https://github.com/RyanYahya/orchestra). Orchestra runs the same workflow across many tools (Claude Code, Codex, Gemini, Cursor…) on a lowest-common-denominator base. Orca drops the cross-tool layer and rebuilds the workflow on Codex's own primitives — **native subagents, Agent Skills, plugins, the desktop app's Automations and Worktrees** — so it fits Codex like a glove.

A pod of orcas hunts in coordination. So does orca: every phase you ship is independently reviewed by a pod of specialist subagents before it lands.

---

## Why orca

- **The audit is native.** After each phase, orca spawns parallel read-only specialist subagents (`spawn_agent` / `wait` / `close_agent`, gated by the on-by-default `features.multi_agent`) to review the diff. Self-review never substitutes; a phase that fails review is **BLOCKED**, not quietly committed.
- **State on disk, not in memory.** Everything lives under `.orca/` — `status.json` (single source of truth), `Plan.md`, decisions, audit history. Any surface (app, CLI, IDE) reads the same files.
- **Desktop-app-first.** Execution runs unattended as a scheduled **Automation** on a background **Worktree**; you review and resolve in the app's Review pane and Triage.
- **CLI escape hatch.** A `codex exec` phase-runner gives you continuous, headless, CI-friendly runs the app can't (machine-off, back-to-back, structured output).
- **Lean by design.** Built on Matt Pocock's and OpenAI's skill-authoring doctrine: one model-invoked router skill, progressive disclosure into `references/`, mechanical steps pushed into deterministic scripts, a shared vocabulary.

## Requirements

- Codex CLI / app **0.141+** (subagents, skills, plugins).
- `jq` and `git` on `PATH` (the workflow scripts use them).

## Install

**1. The skills** (`$orca`, `$simplify`) — via the plugin marketplace:

```bash
codex plugin marketplace add RyanYahya/orca
codex plugin add orca@orca
```

**2. The per-repo workspace** (`.orca/` scripts, templates, profiles) — run once in your repo:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RyanYahya/orca/main/install.sh)
```

Then start: `$orca plan <task>`. For the desktop app, run `$orca app-setup` to wire up the Automations and worktree.

## The workflow

```
$orca plan <task>      research (parallel subagents) → phased Plan.md → decisions → approval
$orca execute [P#]     per phase: implement → verify → MANDATORY subagent audit → scoped commit
$orca resolve          fix a BLOCKED phase, then re-audit
$orca revise           change the plan mid-flight when reality diverges
$orca docs-sync        bring per-directory AGENTS.md back in sync
$orca agent <spec>     create a specialist audit lane in .orca/agents/
$orca archive          file the finished workflow under .orca/workflows/archived/
$simplify [target]     cleanup-only review (quality, not correctness — never replaces the audit)
```

Update orca natively: `codex plugin marketplace upgrade && codex plugin add orca@orca` (your `.orca/workflows/` are untouched).

## Desktop-app-first

Codex can't trigger on a git push (no event triggers yet), so orca drives execution on a **schedule**:

- **Execute Automation** — a *project* automation on a *dedicated background worktree*, on a cron schedule, whose prompt is `$orca execute-headless`. Each tick advances exactly one audited phase; it no-ops once the workflow is `COMPLETED` or `BLOCKED`. Sandbox **must** be `workspace-write`.
- **Heartbeat Automation** — a cheap poll that reads `status.json` and notifies when a phase goes `BLOCKED` or the workflow `COMPLETED` (compensating for the missing event triggers). Results land in **Triage**.
- **Worktree** — one per workflow, branched `orca/<task-slug>`; phases commit sequentially; merge back via the Review pane or Handoff at archive.

`$orca app-setup` prints the exact recipe; templates are in `plugins/orca/templates/automations/`.

> Automations run only while the machine is on and the app is running. For overnight/CI, use the CLI runner: `bash .orca/scripts/phase-runner.sh`. If Orca isn't in the app's Plugins sidebar (known Codex bug), `$orca …` still works from the composer.

## How the audit works

1. `select-audit-agents.sh` reads `.orca/audit-map.json` → the specialist lanes for this phase (always at least `code-auditor`).
2. One read-only subagent per lane, in parallel, each loading its brief from `.orca/agents/<lane>.md` and returning a strict JSON verdict (`.orca/audit.schema.json`).
3. Any `blocking` finding → `Audit_Issues.md` + status `BLOCKED`. All `APPROVED` → cheap advisory fixes applied, recurring patterns appended to `Advisory_Notes.md`, phase committed.

Fallback ladder if native subagents are ever unavailable: `codex exec review` → orchestrated `codex exec` audit processes → **BLOCK** (never self-review-and-pass).

## Repository layout

```
plugins/orca/                  the Codex plugin
├── .codex-plugin/plugin.json  manifest (skills + interface)
├── skills/
│   ├── orca/                  router skill → references/<command>.md (progressive disclosure)
│   └── simplify/              standalone cleanup skill ($simplify)
├── scripts/                   the bash+jq state machine (installed into .orca/scripts/)
├── templates/                 audit-map, audit schema, starter agents, automation + worktree templates
└── profiles/                  orca-exec / orca-audit Codex profiles
.agents/plugins/marketplace.json   the marketplace entry
install.sh                     installs .orca/ into a target repo
```

Installed into your repo as `.orca/` (scripts + `audit-map.json` + `agents/` + `workflows/`; only `workflows/current/` is gitignored).

## Lineage & philosophy

Workflow and on-disk state model from **[orchestra](https://github.com/RyanYahya/orchestra)** by Rayyan Alyahya. Skill design follows **Matt Pocock's** "art of the skill" and OpenAI's own `skill-creator` doctrine: the context window is a public good — keep the always-loaded surface tiny, disclose progressively, and turn mechanical steps into deterministic scripts.

## License

MIT © Rayyan Alyahya. See [LICENSE](LICENSE).
