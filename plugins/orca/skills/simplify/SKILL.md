---
name: simplify
description: Cleanup-only review of changed code for reuse, simplification, efficiency, and altitude, applying behavior-preserving fixes. Quality only — it does not hunt for correctness or security bugs (that is orca's audit). Use when the user asks for "$simplify", "/simplify", a simplification or cleanup pass, or when an orca phase step says to run simplify over the diff.
---

# Simplify

Improve the quality of changed code — do not change behavior, and do not hunt for correctness or security bugs (that is the orca phase audit, `references/audit.md` in the orca skill). Review the diff across four angles, then apply only the safe cleanups.

## Phase 0 — Gather the diff

Determine the review scope, in order:

1. If a target (PR number, branch, path) was given, review that.
2. Otherwise run `git diff @{upstream}...HEAD`.
3. If there is no upstream, try `git diff main...HEAD`, then `git diff HEAD~1`.
4. If there are uncommitted changes, also include `git diff HEAD`.

## Phase 1 — Review with four lanes in parallel

Spawn four read-only subagents in parallel, one per angle, using Codex's native subagents: call `spawn_agent` for each lane (the user asking for simplify authorizes this), pass each the diff and the angle brief from `references/lanes.md`, then `wait` for all and `close_agent` each. If subagents are unavailable, do four separate local passes with the same four headings — do not collapse them into one.

The four angles (full briefs in `references/lanes.md`): **reuse**, **simplification**, **efficiency**, **altitude**.

Each lane returns findings as:

```
- file: path/to/file
  line: 123
  angle: reuse | simplification | efficiency | altitude
  summary: one-line issue
  fix: concrete behavior-preserving cleanup
```

## Phase 2 — Apply

Wait for all lanes, dedupe findings that point at the same line or mechanism, and apply each safe cleanup directly. Skip anything that would change behavior, needs work outside the diff, or is a false positive — note skips briefly. Finish with a short summary: cleanups applied, findings skipped (with reason), or confirmation the diff was already clean.
