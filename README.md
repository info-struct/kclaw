# KClaw

![Kclawlogo-small](C:\Users\gryan\Documents\Kclawlogo-small.png)

**Kubernetes-native assistant.** Persistent agent pods, centralized credential management, multi-tenant IAM, and a full web admin UI. For family and small business up to 100 users using AWS and AWS Bedrock services. (Open router support coming soon)

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

## Requirements

- Ubuntu 26.x Linux on AWS or RasberryPi Bookworm or latter. 
- Kubernetes 1.24+ (tested on k3s on ARM and X86 ) 
- Namespace: `kclaw`
- Orchestrator node selector: `kubernetes.io/hostname` (agents pin to same node for hostPath access)
- Agent pods run as UID 1000 (Claude CLI refuses `--dangerously-skip-permissions` as root)

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
- Credentials delivered to agent pods at startup via Service Account token
- Oauth proxy and management interface

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
- Team Virtual Employ SOP and Persona based tasks

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

## Setting up slack 

#### Go to the [Slack API Portal](https://api.slack.com/apps?new_app=1).

- Click **Create New App** and select **From scratch**.
- Enter your app name G-eves and select your target Slack workspace.
- Click **Create App**. 

- Get the app Token starts with xapp-???????????? and keep it for latter. 

- Scroll back up and click **Install to Workspace**, then authorize the app.
- Goto Oauth & Permission on the right side under Features
- Copy your **Bot User OAuth Token** (`xoxb-...`) and keep it secret.
- Now on the right click the App Manifest to configure your apps behavior. 

- Apply the following app manifest to app.slack.com to your G-eves application to give it permission to talk to the backend 

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

- Go back to Oauth & Permissions and Reinstall your OAuth Token to your org by pressing Reinstall to button. 

## Installing backend

You will need the following:

- AWS access and secret keys for bedrock or anthropic api key
- The Oauth Slack and App slack keys. 
- Brave Search API key
- Option OpenAI key for Wisperflow
- Clone the repo https://github.com/info-struct/kclaw

Run the following command tar -xvf kclaw-installer.tar.gz

cd kclaw

sudo ./install.sh 

## License

**KClaw FSL ALv2" 

- Free for personal and small business use (up to 30 agents/tenents)
- No selling, leasing, or sub-licensing as a standalone product
- Enterprise license required for >30 tenants or commercial SaaS use

See [LICENSE](LICENSE) for full terms.
