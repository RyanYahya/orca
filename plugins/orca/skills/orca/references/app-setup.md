# orca app-setup

Set orca up for the **Codex desktop app** (the primary surface): install `.orca/` into the repo, make the config the app inherits correct, then create the two Automations that drive unattended execution. Terms: `references/GLOSSARY.md`.

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

## Step 3 — Create the EXECUTE automation (the unattended driver)

If the Codex app exposes the `automation_update` tool, use it instead of sending the user through the UI. First look for an existing automation named `orca execute`; update it if found, otherwise create it. Use:

- **Kind:** cron.
- **Workspace:** this repo.
- **Execution environment:** worktree.
- **Schedule:** every 15 minutes during weekday working hours (or daily at 9am if the user asks for a slower cadence).
- **Reasoning effort:** high.
- **Prompt:** `$orca execute-headless` then: *"Advance exactly ONE pending phase of the active .orca workflow, run the mandatory subagent audit, then stop. If status.json status is COMPLETED or BLOCKED, do nothing and report that to Triage."*

When calling the tool, put the workspace, worktree environment, schedule, status, and reasoning effort in tool fields, not in the prompt. Use an active cron schedule equivalent to "every 15 minutes during weekday working hours" (for example `FREQ=MINUTELY;INTERVAL=15;BYDAY=MO,TU,WE,TH,FR;BYHOUR=9,10,11,12,13,14,15,16,17,18`) but do not show raw schedule strings to the user.

If `automation_update` is unavailable, create it manually in the app: **Automations → New**, using `.orca/automations/execute.template.json`. It must be a project automation scoped to this repo, running on a dedicated background worktree with `workspace-write`.

One phase advances per tick; the cron cadence is the loop. Ticks no-op once the workflow is COMPLETED or BLOCKED. Results land in **Triage**.

## Step 4 — Create the HEARTBEAT automation (compensates for no event triggers)

Orca can't fire *on* BLOCKED, so add a cheap poller. If `automation_update` is available, update or create an automation named `orca heartbeat`:

- **Kind:** cron.
- **Workspace:** this repo.
- **Execution environment:** local.
- **Schedule:** every 30 minutes.
- **Reasoning effort:** low.
- **Prompt:** *"Read .orca/workflows/current/status.json. If status is BLOCKED or COMPLETED, summarize it in Triage and run `bash .orca/scripts/notify.sh '<status>: <task>'`. Otherwise do nothing."*

When calling the tool, put the workspace, local execution environment, schedule, status, and reasoning effort in tool fields, not in the prompt. Use an active cron schedule equivalent to "every 30 minutes" (for example `FREQ=MINUTELY;INTERVAL=30`) but do not show raw schedule strings to the user.

If `automation_update` is unavailable, create it manually from `.orca/automations/heartbeat.template.json`.

## Step 5 — Worktree branch (one per workflow)

At plan time, create the workflow's worktree off the base branch and immediately use **Create branch here** → `orca/<task-slug>` (escape detached HEAD, or phase-commit SHAs get stranded). **Pin** the worktree so the 15-worktree retention can't prune a multi-day run. Phases commit sequentially to that branch; at `archive`, merge back via the Review pane (push → PR) or Handoff, then unpin.

## Step 6 — Confirm and note the caveats

Tell the user: the execute + heartbeat Automations are set; orca will advance one audited phase per tick and surface BLOCKED/COMPLETED in Triage. Caveats to state plainly:

- Automations run only while the **machine is on, the app is running, and the repo is on disk** (no cloud durability). For overnight/CI runs, use the CLI phase-runner: `bash .orca/scripts/phase-runner.sh`.
- If Orca doesn't appear in the app's **Plugins** sidebar (known bug #16783), it still works — invoke `$orca …` from the composer.
- Keep any `AGENTS.override.md` in a worktree **lean** (a large one can hang worktree pre-flight).
