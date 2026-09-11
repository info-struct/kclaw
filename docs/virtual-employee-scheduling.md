# Virtual Employees & Task Scheduling

This guide covers how KClaw's virtual employee (persona) system and task scheduling work, and how to configure them for your team.

---

## Overview

KClaw has two complementary scheduling systems:

- **Team-level scheduled jobs** — a persona (virtual employee) runs a standing task on a cron schedule, unsupervised, with team context
- **User-level scheduled tasks** — a personal agent runs a recurring prompt on behalf of a specific user

Both dispatch an isolated agent pod, inject the right identity and credentials, execute the prompt, and deliver the result to a Slack or Telegram channel.

---

## Virtual Employees (Personas)

### What is a Persona?

A persona is a role definition scoped to a team. It provides:

- A **name** and **role** (`architect`, `dev`, `ops`, or `custom`)
- **Instructions** — a role SOP text injected into the agent's `CLAUDE.md` at startup
- An optional **model preference** (overrides the team default)

When a scheduled job fires, the persona's instructions are merged into the agent's system context. Every run of that job behaves as the same virtual employee with consistent identity, knowledge, and procedure.

### Creating a Persona

In the Admin UI navigate to **Teams → Manage → Personas** and click **Add Persona**.

Fields:
- **Name** — e.g. `DevOps Specialist`, `Daily Researcher`
- **Role** — choose from `architect`, `dev`, `ops`, or `custom`
- **Instructions** — the SOP text the agent receives. Write it as you would a `CLAUDE.md`. Example:

```
You are a DevOps specialist for the Engineering team.

Your responsibilities:
- Monitor infrastructure health and flag anomalies
- Debug deployment issues and summarize findings
- Optimize resource usage and surface cost recommendations

Always end your report with a bullet list of action items.
```

- **Model Preference** — optional. Leave blank to use the team's default model.

### How Persona Instructions Are Injected

At pod startup, the orchestrator fetches the persona via CredRouter and injects:

- `KCLAW_PERSONA_INSTRUCTIONS` — the SOP text
- `KCLAW_PERSONA_ID` — the persona UUID
- `KCLAW_TEAM_ID` — the team identifier

The agent runner writes these into `/workspace/group/CLAUDE.md` before the first message is processed. Claude Code loads this file automatically as system context.

If the team has a shared PVC, `/workspace/shared/CLAUDE.md` is also merged in via the SDK's `additionalDirectories` flag, giving the agent team-wide context on top of the persona role.

---

## Team-Level Scheduled Jobs

### Setup Flow

**Step 1 — Create a team** (if not already done). See `team-setup.md`.

**Step 2 — Create a persona** (see above).

**Step 3 — Create a job template** in the Admin UI under **Teams → Manage → Jobs**.

Fields:
- **Name** — e.g. `Daily Infrastructure Check`
- **Persona** — select the persona this job runs as
- **Notify** — the Slack or Telegram channel/DM to deliver results to

**Step 4 — Create a schedule** under **Teams → Manage → Schedules**.

Fields:
- **Name** — e.g. `Daily 9 AM`
- **Job Template** — select the template from Step 3
- **Cron Expression** — standard 5-field cron (evaluated in the cluster timezone)

| Example | Meaning |
|---------|---------|
| `0 9 * * 1-5` | 9:00 AM weekdays |
| `0 */4 * * *` | Every 4 hours |
| `30 8 * * 1` | 8:30 AM every Monday |
| `0 0 1 * *` | 1st of every month |

### Execution Flow

```
Schedule fires (cron due)
  ↓
Orchestrator polls user schedules every 60s
  ↓
Enriches with: tenantIdentifier, teamPvcName, personaInstructions
  ↓
POST /admin/jobs/dispatch
  ↓
K8s Job created → agent pod starts
  ↓
Persona instructions written to CLAUDE.md
  ↓
Prompt executed by agent
  ↓
Result delivered to notifyJid (Slack DM / channel)
```

---

## User-Level Scheduled Tasks

User-level schedules let individual users set up recurring prompts tied to their personal agent (and optionally a team persona).

### Setting Up in the Admin UI

Navigate to **Settings → My Tasks** (or via the tenant management page):

1. Write a standing prompt — e.g. `Summarize the top 5 items in my inbox and flag anything urgent`
2. Set a cron expression — e.g. `0 8 * * 1-5` (8 AM weekdays)
3. Select a notification channel (Slack DM, Telegram)
4. Optionally assign a persona for the agent to run as

The orchestrator polls enabled user schedules every 60 seconds. When a schedule is due it dispatches a oneshot pod, runs the prompt, and sends the result to the configured channel.

---

## Agent-Side Task Scheduling (ScheduleTask Tool)

Inside an agent conversation, users (or the agent itself) can schedule future tasks using the built-in `ScheduleTask` MCP tool. This does not require any admin setup.

### Schedule Types

| Type | Value format | Example |
|------|-------------|---------|
| `cron` | Standard cron expression | `0 9 * * *` |
| `interval` | Duration string | `4h`, `30m`, `1d` |
| `once` | ISO 8601 datetime | `2026-10-01T09:00:00Z` |

Tasks written via `ScheduleTask` are persisted to disk in the agent's group directory and synced to the orchestrator database on the next poll. They survive pod restarts.

### The /loop Command

`/loop` is a Claude Code built-in that keeps the agent running across iterations of a long-running task. Use it for work that needs to poll, monitor, or iterate over time within a single session. It is distinct from `ScheduleTask` — `/loop` runs continuously within a session, while `ScheduleTask` fires on a schedule between sessions.

---

## Timezone Configuration

All cron expressions are evaluated in the timezone set on the orchestrator:

```yaml
# In your .env or orchestrator deployment
TIMEZONE=America/New_York
```

Default is UTC if not set.

---

## Troubleshooting

**Scheduled job not firing**

- Confirm the schedule is enabled in the Admin UI.
- Check the orchestrator logs for the poll cycle: `kubectl logs -n kclaw deploy/kubeclaw-orchestrator | grep user-schedule`.
- Verify the cron expression is valid (use [crontab.guru](https://crontab.guru) to test).
- Check that `lastRunAt` is not already set for the current occurrence (prevents double-fire within the same 60-second window).

**Persona instructions not appearing**

- Confirm the tenant has a `PERSONA_ID` set in tenant configs (Admin UI → Tenant → Edit).
- Check pod env vars: `kubectl exec -n kclaw <pod> -- env | grep KCLAW_PERSONA`.
- Confirm `/workspace/group/CLAUDE.md` exists inside the running pod.

**Result not delivered to Slack/Telegram**

- Verify the `notifyJid` matches an active platform identifier for the tenant (Admin UI → Tenant → Identifiers).
- Check orchestrator logs for `sendMessage` errors after the job completes.

**Task created via ScheduleTask not appearing in orchestrator**

- The task is written to `/workspace/group/scheduled_tasks.json` by the agent. The orchestrator syncs this file on the next poll cycle.
- Check the file exists: `kubectl exec -n kclaw <pod> -- cat /workspace/group/scheduled_tasks.json`.
- Verify the IPC watcher is running: `kubectl logs -n kclaw deploy/kubeclaw-orchestrator | grep ipc`.
