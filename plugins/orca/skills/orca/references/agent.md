# orca agent

**Request:** the words after `agent` (e.g. `prisma-expert for database review`).

Create a project specialist brief in `.orca/agents/<name>.md`. These briefs are what the audit fan-out (`references/audit.md`) loads into each `spawn_agent` lane, and what `select-audit-agents.sh` matches against `.orca/audit-map.json`. Terms: `references/GLOSSARY.md`.

## Step 1 — Parse the request

Extract a kebab-case `name` and the domain of expertise. Read the existing roster (`ls .orca/agents/`) and the starter `code-auditor.md` / `codebase-researcher.md` as the pattern.

## Step 2 — Research the domain (optional)

If the domain has external docs and a docs/MCP source is available (e.g. the `openai-docs` skill or a Context7 MCP server), pull current best-practices to ground the brief. Do not make MCP a hard dependency — if it's unavailable, write from codebase patterns and skip external citation.

## Step 3 — Write `.orca/agents/<name>.md`

```markdown
---
name: <name>
description: <one line — the domain and exactly when this lane should audit. select-audit-agents.sh matches on this; be specific.>
---

You are a read-only <domain> specialist reviewing one phase's diff. <one line of identity>.

## Focus
- <the 3–5 things this specialist checks that a general auditor wouldn't>

## Output
Return ONLY a JSON object matching `.orca/audit.schema.json`:
{ "lane": "<name>", "verdict": "APPROVED|ISSUES", "summary": "…", "blocking": ["…"], "advisory": ["…"] }
Do not modify files.
```

Keep it short — every lane is a real model thread, and the brief is loaded in full.

## Step 4 — Wire it in (optional) and report

To make the lane fire automatically, add it to `.orca/audit-map.json` — as a `defaultAgents` entry (runs every phase) or a path rule: `{ "paths": ["src/db/**"], "agents": ["<name>"] }`. Report the path created, how it's wired, and that it'll be selected by `select-audit-agents.sh` on matching phases.
