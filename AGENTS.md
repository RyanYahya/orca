# AGENTS.md — working on the orca repo

This repo **is** the orca Codex plugin (it is not a project that orca manages). Layout and rationale are in `README.md`.

## Where things live

- `plugins/orca/.codex-plugin/plugin.json` — the manifest. Allowed keys only (see `~/.codex/skills/.system/plugin-creator/references/plugin-json-spec.md`); **never add `hooks`** — validation rejects it.
- `plugins/orca/skills/orca/SKILL.md` — the one model-invoked router. Keep its `description` tight (it's always-loaded context) and its body lean; real procedures live in `skills/orca/references/<command>.md`.
- `plugins/orca/skills/*/agents/openai.yaml` — app UI metadata. `simplify` sets `policy.allow_implicit_invocation: false` (user-invoked only). Do **not** put `disable-model-invocation` in SKILL.md frontmatter — validation requires it absent/false.
- `plugins/orca/scripts/` — the bash+jq state machine, installed into a target repo's `.orca/scripts/`. `PROJECT_ROOT` is computed three levels up from `scripts/lib/`.
- `plugins/orca/templates/`, `profiles/` — copied into `.orca/` and `~/.codex/` by `install.sh`.

## Conventions

- One shared vocabulary — see `skills/orca/references/GLOSSARY.md`. Use those terms in scripts, references, and status fields.
- Mechanical/checkable steps belong in scripts, not prose. References orchestrate scripts; they don't reimplement them.
- The audit procedure lives in exactly one place: `skills/orca/references/audit.md`. Other references point to it.

## Validate before shipping

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/orca
for f in plugins/orca/scripts/*.sh plugins/orca/scripts/lib/*.sh install.sh; do bash -n "$f"; done
```
