# orca app-setup

Set orca up for the **Codex desktop app** (the primary surface): install `.orca/` into the repo, make the config the app inherits correct, and prepare the headless automation recipes. Terms: `references/GLOSSARY.md`.

## Step 1 — Install `.orca/` into the repo

If `.orca/` doesn't exist, run the installer (it copies scripts/templates/profiles, creates the workflow dirs, appends an AGENTS.md pointer, sets project trust + sandbox, and adds the `.gitignore` rule):

```
bash <(curl -fsSL https://raw.githubusercontent.com/RyanYahya/orca/main/install.sh)
```

(Or, from a clone of orca, run from your project root: `bash /path/to/orca/install.sh --target "$(pwd)"`.) The `$orca`/`$simplify` skills themselves come from the plugin: `codex plugin marketplace add RyanYahya/orca && codex plugin add orca@orca`.

## Step 2 — Make the inherited config correct (decisive)

The app inherits your **base** `~/.codex/config.toml` (and project `.codex/config.toml`) — but app **profile selection is not guaranteed**, so put orca's requirements in the base/project config, not only in a named profile. The installer writes these; verify they're present:

```toml
# project .codex/config.toml (or base ~/.codex/config.toml)
approval_policy = "never"
sandbox_mode = "workspace-write"   # REQUIRED — a read-only sandbox makes phases fail to write/commit
[features]
multi_agent = true                  # native audit fan-out (default on; assert it)
[agents]
max_threads = 6                     # audit lane concurrency
max_depth = 1                       # auditors don't recurse
```

Also ensure the project is **trusted** so project config + skills load: `[projects."<abs repo path>"] trust_level = "trusted"` in `~/.codex/config.toml`.

## Step 3 — Prepare, but do not create, headless Automations

Do **not** create `orca execute` or `orca heartbeat` during app setup. They are recurring jobs, so they should only exist after the user opts into headless execution by invoking `$orca execute-headless`.

Keep `.orca/automations/execute.template.json` and `.orca/automations/heartbeat.template.json` available as the manual fallback recipes. The lifecycle is defined in `references/automation-lifecycle.md`:

- `$orca execute-headless` creates or enables the two Automations when `automation_update` is available.
- The execute Automation advances one audited phase per tick.
- The heartbeat Automation reports `BLOCKED`/`COMPLETED`.
- When the workflow reaches `COMPLETED`, both Automations are paused.

If the user asks to start unattended execution now, tell them to run `$orca execute-headless`; do not create the Automations from `$orca app-setup`.

## Step 4 — Worktree branch (one per workflow)

At plan time, create the workflow's worktree off the base branch and immediately use **Create branch here** → `orca/<task-slug>` (escape detached HEAD, or phase-commit SHAs get stranded). **Pin** the worktree so the 15-worktree retention can't prune a multi-day run. Phases commit sequentially to that branch; at `archive`, merge back via the Review pane (push → PR) or Handoff, then unpin.

## Step 5 — Confirm and note the caveats

Tell the user: Orca is installed and the app config is ready. The execute + heartbeat Automations are **not** created until `$orca execute-headless` is invoked; once enabled, they advance one audited phase per tick, mirror the active phase with `update_plan` when available, surface BLOCKED/COMPLETED in Triage, and pause themselves when the workflow completes. Caveats to state plainly:

- Automations run only while the **machine is on, the app is running, and the repo is on disk** (no cloud durability). For overnight/CI runs, use the CLI phase-runner: `bash .orca/scripts/phase-runner.sh`.
- If Orca doesn't appear in the app's **Plugins** sidebar (known bug #16783), it still works — invoke `$orca …` from the composer.
- Keep any `AGENTS.override.md` in a worktree **lean** (a large one can hang worktree pre-flight).
