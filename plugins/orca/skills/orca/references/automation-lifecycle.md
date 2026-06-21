# orca automation lifecycle

Desktop-app Automations are an opt-in headless execution driver. `$orca app-setup` prepares config and templates; it does not create recurring jobs. `$orca execute-headless` is the activation point.

## Rules

- Create or enable `orca execute` and `orca heartbeat` only when the user invokes `$orca execute-headless` in the Codex app and the `automation_update` tool is available.
- If `automation_update` is unavailable, do not pretend the jobs exist. Tell the user how to create them manually from `.orca/automations/*.template.json`.
- Prefer updating existing automations by name over creating duplicates.
- Leave both automations `ACTIVE` while the workflow is `PENDING` and phases remain.
- When `status.json.status == COMPLETED`, pause both automations. This applies both at the start of a headless tick and immediately after `complete-phase.sh` finishes the final phase.
- When the workflow is `BLOCKED`, pause `orca execute` so it stops no-oping. Keep or pause `orca heartbeat` according to the user's preference; the default is to keep it active until it reports the block once, then pause it to avoid repeated Triage noise. The user can run `$orca resolve` and then `$orca execute-headless` to resume headless execution.
- Do not pin or override the model in automation creation. Inherit the app/base Codex model selection; only set reasoning effort.

## Execute Automation

Name: `orca execute`

- **Kind:** cron
- **Workspace:** this repo
- **Execution environment:** worktree
- **Schedule:** every 15 minutes during weekday working hours, unless the user requested a different cadence
- **Status:** `ACTIVE` when enabled by `$orca execute-headless`; `PAUSED` when the workflow completes
- **Reasoning effort:** high
- **Prompt:** `$orca execute-headless` then: `Advance exactly ONE pending phase of the active .orca workflow, mirror progress with update_plan if available, run the mandatory subagent audit, then stop. If status.json status is COMPLETED or BLOCKED, disable the appropriate orca automations and report that to Triage.`

## Heartbeat Automation

Name: `orca heartbeat`

- **Kind:** cron
- **Workspace:** this repo
- **Execution environment:** local
- **Schedule:** every 30 minutes
- **Status:** `ACTIVE` when enabled by `$orca execute-headless`; `PAUSED` after reporting `COMPLETED`, and by default after one `BLOCKED` notification
- **Reasoning effort:** low
- **Prompt:** `Read .orca/workflows/current/status.json. If status is BLOCKED, summarize it in Triage, run bash .orca/scripts/notify.sh 'BLOCKED: <task>', pause the orca execute automation, then pause this heartbeat to avoid repeated notifications. If status is COMPLETED, summarize it in Triage, run bash .orca/scripts/notify.sh 'COMPLETED: <task>', then pause both orca automations. Otherwise do nothing.`
