# KClaw

![Kclawlogo](C:\Users\gryan\Documents\Kclawlogo.jpg)

**Kubernetes-native assistant.** Persistent agent pods, centralized credential management, multi-tenant IAM, and a full web admin UI. For family and small business up to 100 users using AWS and AWS Bedrock services. (Open router support comming soon)

Running in production on k3s (X_86, Graviton, RaspberryPI). 
---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (kclaw namespace)                    │
│                                                          │
│  ┌─────────────────┐   ┌─────────────────────────────┐   │
│  │  KClaw Admin UI │   │  Orchestrator               │   │
│  │  (kclaw-admin-  │   │  - Channels (Slack, DM)     │   │
│  │   ui.local)     │   │  - Message routing          │   │
│  │  - Dashboard    │   │  - Pod lifecycle management │   │
│  │  - IAM / RBAC   │   │  - Task scheduler + CronJob │   │
│  │  - Tenants      │   │  - Admin API (port 3002)    │   │
│  │  - Teams        │   └────────────┬────────────────┘   │
│  │  - MCP servers  │                │ HTTP POST /message │
│  │  - Vault        │                ↓                    │
│  │  - Sessions     │   ┌────────────────────────────┐    │
│  └────────┬────────┘   │  Agent Pod (per group)     │    │
│           │            │  - Claude Agent SDK        │    │
│           │ REST       │  - HTTP server :3000       │    │
│           ↓            │  - MCP servers (stdio/SSE) │    │
│  ┌─────────────────┐   │  - Session ID in memory    │    │
│  │  CredRouter     │←──│  - POST /reload endpoint   │    │
│  │  - IAM (JWT)    │   └────────────────────────────┘    │
│  │  - Tenant vault │                                     │
│  │  - Team config  │   LiteLLM:  api.anthropic.com /     │
│  │  - MCP configs  │             bedrock.aws.com         │
│  │  - Token limits │                                     │
│  └─────────────────┘                                     │
└──────────────────────────────────────────────────────────┘
```

### Components

| Component | Image | Port | Ingress |
|-----------|-------|------|---------|
| CredRouter | `gryanfawcett/kubeclaw-credrouter:latest` | 3001 (internal) | — |
| Orchestrator | `gryanfawcett/kubeclaw-orchestrator:latest` | 8787, 3002 | `kubeclaw-admin.local` |
| Admin UI | `gryanfawcett/kclaw-admin-ui:latest` | 3003 | `kclaw-admin-ui.local` |
| Agent pods | `gryanfawcett/kubeclaw-agent:latest` | 3000 (internal) | — |

---

## Features

**Messaging**
- Slack DM and Slack channels
- Persistent agent pods — session context kept in memory across messages
- First message: ~21s (pod creation + startup). Subsequent: ~3–5s

**Credential & Config Management (CredRouter)**
- Admin UI and user portal
- Per-tenant and per-team encrypted vault
- Team-scoped MCP server registry
- Config merge: Global < Team < User
- Credentials delivered to agent pods at startup via ServiceAccount token

Admin UI
- Dashboard: health, token spend, active pods, activity feed
- Tenant management: vault, MCP toggles, token budgets, usage charts
- Team management: create teams, assign members, provision PVCs
- Settings: IAM users, team vault, MCP server rack (command/args/url), skill browser
- Sessions: list, inspect, invalidate, kill, **Reload Config** (live credential push)
- IAM: invite flow, RBAC (admin / team_lead / user), SAML SSO

**Scheduled Tasks**

- Agent uses `ScheduleTask` MCP tool to persist tasks to disk
- Kubernetes CronJob executes due tasks every minute (scales to any number of users)
- `/loop` command working end-to-end

**MCP Servers**

- stdio (npx, node) and SSE transports
- Registered per-team or per-tenant via Admin UI
- Vault keys injected into agent `process.env` — MCP subprocesses inherit them
- Live reload without pod restart via **Sessions → Reload Config**

**Persona & CLAUDE.md**

- Users set personal AI instructions via `/my-settings → Persona`
- Admins set team instructions via tenant `CLAUDE_MD_CONTENT` config key
- Both written to `/workspace/group/CLAUDE.md` at pod startup (combined when both set)

---

## Getting started



---

## Setting up slack bot

1. Register the App on Slack



- Go to the [Slack API Portal](https://api.slack.com/apps?new_app=1).
- Click **Create New App** and select **From scratch**.
- Enter your app name and select your target Slack workspace.
- Click **Create App**. [[1](https://api.slack.com/apps?new_app=1), [2](https://www.youtube.com/watch?v=Fnj7Qq8AHnw&t=72), [3](https://medium.com/applied-data-science/how-to-build-you-own-slack-bot-714283fd16e5), [4](https://www.sprinklr.com/help/articles/slack/how-to-create-a-slack-bot/6543460bb1f59867f3be1ba2)]
- Configure Permissions and Scopes

- Navigate to **OAuth & Permissions** in the left sidebar.
- Scroll down to **Scopes** and add `Bot Token Scopes` like `chat:write` (to send messages) and `channels:read`.
- Scroll back up and click **Install to Workspace**, then authorize the app.
- Copy your **Bot User OAuth Token** (`xoxb-...`) and keep it secret. [[1](https://medium.com/applied-data-science/how-to-build-you-own-slack-bot-714283fd16e5), [2](https://www.youtube.com/watch?v=uycMHMBAShc&t=210), [3](https://www.sprinklr.com/help/articles/slack/how-to-create-a-slack-bot/6543460bb1f59867f3be1ba2)]
- Write and Host Your Bot Code

- Set up a project using a framework like Slack's Bolt for Python or Node.js.
- Store your `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` safely in environment variables.
- Listen for incoming events (like mentions or direct messages) or set up a Request URL via Event Subscriptions.
- Deploy your code to a hosting provider or use Socket Mode so Slack can communicate with your local or cloud application securely

To setup slack you need to have a couple sites handy and generated a bot app and application key

1: goto https://api.slack.com/apps and create a new app name it G-eves for your Ai Assistant

Create the App-level Token typically starts with xapp-??????????

2: Also an oauth level token

xoxb-?????????????????



Apply the following app manifest to app.slack.com to your G-eves application 

```
{
    "display_information": {
        "name": "G-eves",
        "description": "Personal AI Assistant"
    },
    "features": {
        "app_home": {
            "home_tab_enabled": false,
            "messages_tab_enabled": true,
            "messages_tab_read_only_enabled": false
        },
        "bot_user": {
            "display_name": "G-eves",
            "always_online": true
        },
        "slash_commands": [
            {
                "command": "/reload",
                "description": "reloads config",
                "should_escape": false
            },
            {
                "command": "/reset",
                "description": "Clears the context",
                "should_escape": false
            }
        ]
    },
    "oauth_config": {
        "scopes": {
            "bot": [
                "users:read.email",
                "channels:history",
                "channels:read",
                "chat:write",
                "commands",
                "files:read",
                "files:write",
                "groups:history",
                "groups:read",
                "im:history",
                "im:read",
                "users:read"
            ]
        },
        "pkce_enabled": false
    },
    "settings": {
        "event_subscriptions": {
            "bot_events": [
                "message.channels",
                "message.groups",
                "message.im"
            ]
        },
        "interactivity": {
            "is_enabled": true
        },
        "org_deploy_enabled": false,
        "socket_mode_enabled": true,
        "token_rotation_enabled": false,
        "is_mcp_enabled": false
    }
}
```



## Installing backend







## Onboarding a User

1. **Settings → IAM → Invite User** — set role, optionally link to a tenant, copy the link
2. User accepts invite, receives temporary password, forced to change on first login
3. If tenant wasn't linked at invite time: **Settings → IAM Users → Link** next to the user row (user must log out/in after)

---

## Registering an MCP Server

1. **Settings → MCP Server Rack** → select team → Register New MCP Server
   - `stdio`: name, command (e.g. `npx`), args (e.g. `-y @example/weather-mcp`)
   - `sse`: name, URL
2. **Settings → Vault** → add the API key the MCP expects (e.g. `WEATHER_API_KEY`)
3. The key is injected into the agent's environment — MCP subprocesses inherit it
4. Use **Sessions → Reload Config** on a running session to push changes without restart

---

## Requirements

- Kubernetes 1.24+ (tested on k3s on ARM and X86 ) 
- Namespace: `kclaw`
- Orchestrator node selector: `kubernetes.io/hostname` (agents pin to same node for hostPath access)
- Agent pods run as UID 1000 (Claude CLI refuses `--dangerously-skip-permissions` as root)

---

## License

**KubeClaw FSL ALv2" 

- Free for personal and small business use (up to 30 agents/tenents)
- No selling, leasing, or sub-licensing as a standalone product
- Enterprise license required for >30 tenants or commercial SaaS use

See [LICENSE](LICENSE) for full terms.
