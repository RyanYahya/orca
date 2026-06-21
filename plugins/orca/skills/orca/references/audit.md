# orca audit

The mandatory, independent review of a phase's diff by parallel specialist subagents. This is orca's core guarantee: **the AI, not the human, does most of the cleanup**, and a phase is never committed on self-review alone. Invoked by `execute` (Step 6b), `execute-headless`, and `resolve`. Terms: `references/GLOSSARY.md`.

## Precondition

`features.multi_agent` is stable and on by default in Codex, so `spawn_agent`/`wait`/`close_agent` are available. The user invoking `execute` (or the automation/runner) IS authorization to spawn subagents — they never auto-spawn. Audit lanes are read-only and don't recurse (`[agents] max_depth = 1`).

## A. Select lanes (deterministic)

```
bash .orca/scripts/select-audit-agents.sh <PID> $(git diff --name-only HEAD)
```

The diff under audit is the uncommitted phase diff (`git diff HEAD`), because audit runs before the phase commit. This reads `.orca/audit-map.json` (phase overrides → path-glob rules → `defaultAgents`), existence-checks each against `.orca/agents/*.md`, and prints one specialist name per line. Empty output ⇒ infer lanes from the changed files and phase name. **Always include at least `code-auditor`.**

## B. Spawn one read-only subagent per lane, in parallel

For each selected lane, `spawn_agent` with a prompt that contains:

- the lane's brief, read from `.orca/agents/<lane>.md`;
- the phase id + name and `git diff --name-only HEAD`;
- `git diff HEAD` and your Step-6a self-review summary (what you already fixed);
- this instruction: *"Review read-only. Return ONLY a JSON object matching `.orca/audit.schema.json`: `{lane, verdict: APPROVED|ISSUES, summary, blocking[], advisory[]}`. `verdict` is APPROVED only if `blocking` is empty. Do not edit files."*

Then `wait` for every spawned lane, collect each child's returned result (its final message), and `close_agent` each when done.

**Completion criteria (do not proceed until both hold):** every selected lane has returned a result, and each result parses as the schema JSON with a `verdict` in `{APPROVED, ISSUES}`. No lane may be left pending.

## C. Consolidate

Merge all lanes' `blocking` and `advisory` lists. The phase verdict is **ISSUES** if any lane reported a non-empty `blocking`, else **APPROVED**.

## D. Decide

**Any blocking ⇒ BLOCK:**
```
# write the consolidated blocking findings to Audit_Issues.md, then:
bash .orca/scripts/record-audit.sh <PID> --issues --issues-file .orca/workflows/current/Audit_Issues.md
```
`record-audit.sh --issues` sets top-level `status = BLOCKED`. Stop here. The user (or `$orca resolve`) addresses it before the phase is committed. In the app, the headless lifecycle pauses `orca execute` on BLOCKED; the heartbeat automation surfaces the block in Triage.

**All approved:**
- For each `advisory` the lanes raised that self-review missed: cheap → fix silently; material → surface to the user; recurring → append to `Advisory_Notes.md` under `## Patterns to avoid`.
- `bash .orca/scripts/record-audit.sh <PID> --approved --auto-fixed N --surfaced N --learned N`
- Return to the caller (execute continues to its commit step).

## Deterministic variant (for the headless runner)

When a script must parse the verdict (not prose), run the audit as its own structured turn so the output is guaranteed-shape JSON:

```
codex exec -p orca-audit --json \
  --output-schema .orca/audit.schema.json -o /tmp/orca-audit.json \
  "<consolidated audit instruction for this phase>"
```

Then branch on `jq -r .verdict /tmp/orca-audit.json`. (Every schema property is `required` and `additionalProperties` is false — Codex rejects partial schemas.)

## Fallback ladder (only if native spawn is unavailable)

Use the highest rung that works; **never** skip to self-review:

1. **Native `spawn_agent` lanes** — the primary path above.
2. **`codex exec review --uncommitted`** (or `--base <baseBranch>`) — one strong general lane.
3. **Orchestrated processes** — run each lane as its own `codex exec -p orca-audit --json --output-schema .orca/audit.schema.json -o lane_<n>.json "<brief>"`, then merge the JSON. Robust and process-isolated; dodges the `max_threads` cap.
4. **No real external review ran ⇒ BLOCK** the phase (write `Audit_Issues.md`, `record-audit.sh --issues`). This is the orca invariant: a phase is never approved by the same context that wrote it.
