# KClaw

![Application Screenshot](Images/Kclawlogo-small.png)

**IT-managed, multi-tenant AI assistant platform for small business and enterprise.** KClaw gives your team a Chief of Staff and researcher — integrating Google Workspace, Slack,calendar, drive, and office tools via a personalized AI assistant per user. Scales to 30 agents on existing Kubernetes infrastructure, managed entirely by IT.

Built for organizations that need **governance, data sovereignty, and cost control** — not a personal agent running on someone's workstation.

**Why KClaw instead of Claude Managed Agents or Microsoft Copilot:**
- **Data sovereignty** — runs on your infrastructure (on-prem, AWS, Raspberry Pi). Conversation data never leaves your cluster.
- **Cost control** — free for up to 30 tenants under FSL-1.1. No per-seat SaaS fees. Pair with AWS Bedrock or OpenRouter to optimize model costs.
- **IT governance** — full RBAC, SAML SSO, audit trails, token budgets per tenant, and credential vault managed by IT — not by individual users.
- **Model-agnostic via LiteLLM** — AWS Bedrock (Anthropic, Titan, Llama), Anthropic API, OpenRouter (Gemini, Mistral, 100+ models). No vendor lock-in.

Running in production on k3s (Graviton, EC2, Raspberry PI 5).
---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (kclaw namespace)                                │
│                                                                         │
│  ┌─────────────────┐   ┌───────────────────────────────────────────┐    │
│  │  KClaw Admin UI │   │  Orchestrator                             │    │
│  │  (kclaw-admin-  │   │  - Channels (Slack)             │    │
│  │   ui.local)     │   │  - Message routing & Pod lifecycle        │    │
│  │  - Dashboard    │   │  - Task scheduler + CronJob               │    │
│  │  - IAM / RBAC   │   │  - Real-time Observability (K8s Watch API)│    │
│  │  - Tenants      │   │  - Admin API (port 3002)                  │    │
│  │  - Teams        │   └────────────┬──────────────────────────────┘    │
│  │  - MCP servers  │                │ HTTP POST /message                │
│  │  - Vault        │                ↓                                   │
│  │  - Sessions     │   ┌───────────────────────────────────────────┐    │
│  └────────┬────────┘   │  Agent Pod (per user/group)               │    │
│           │            │  - Claude Agent SDK & HTTP server :3000   │    │
│           │ REST       │  - MCP servers (stdio/SSE)                │    │
│           ↓            │  - Local SQLite Storage (gtd.db)          │    │
│  ┌─────────────────┐   │  - POST /reload endpoint                  │    │
│  │  CredRouter     │←──┤  ┌─────────────────────────────────────┐  │    │
│  │  - IAM (JWT)    │   │  │ Shared PVCs (subPath mounts)        │  │    │
│  │  - Tenant vault │   │  │ - Team Skills                       │  │    │
│  │  - Team config  │   │  │ - Private Agent State               │  │    │
│  │  - MCP configs  │   │  └─────────────────────────────────────┘  │    │
│  │  - Token limits │   └───────────────────────────────────────────┘    │
│  └─────────────────┘                                                    │
│                        LiteLLM → Bedrock / Anthropic API / OpenRouter           │
└─────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Image | Port | Ingress |
|-----------|-------|------|---------|
| CredRouter | `YOUR_REGISTRY/kubeclaw-credrouter:latest` | 3001 (internal) | — |
| Orchestrator | `YOUR_REGISTRY/kubeclaw-orchestrator:latest` | 8787, 3002 | `kubeclaw-admin.local` |
| Admin UI | `YOUR_REGISTRY/kclaw-admin-ui:latest` | 3003 | `kclaw-admin-ui.local` |
| Agent pods | `YOUR_REGISTRY/kubeclaw-agent:latest` | 3000 (internal) | — |

## Requirements

- Ubuntu 26.x Linux on AWS or RasberryPi Bookworm or latter. 
- Kubernetes 1.24+ (tested on k3s on ARM and X86 ) 
- Namespace: `kclaw`
- Orchestrator node selector: `kubernetes.io/hostname` (agents pin to same node for hostPath access)
- Agent pods run as UID 1000 (Claude CLI refuses `--dangerously-skip-permissions` as root)

## Features

**Native Claude Code Skill Compatibility**

- Any Anthropic-style Claude Code skill works natively out of the box
- Full Claude Code skill ecosystem available without porting or adapting
- Skills run inside isolated agent pods — no cross-contamination between users

**Model Support (via LiteLLM)**

- AWS Bedrock — Anthropic Claude, Titan, Llama
- Anthropic API (direct)
- OpenRouter — Gemini, Mistral, and 100+ models
- Any LiteLLM-supported provider
- Switch models via config — no agent code changes required

**Messaging & Intelligence**

- Slack channels
- Wisper flow audio transcription on slack record function ( with api key )
- **Native Document Support:** Full support for `application/pdf` parsing routed dynamically to Claude 3.5/4.x document blocks
- Persistent agent pods — session context kept in memory across messages
- First message: ~35s (pod creation + startup). Subsequent: ~3–5s

**Credential & Config Management (CredRouter)**

- JWT-authenticated admin UI and user portal
- Per-tenant and per-team encrypted vault
- Team-scoped MCP server registry
- Config merge: Global < Team < User
- Credentials delivered to agent pods at startup via ServiceAccount token

**Admin UI** (`http://kclaw-admin-ui.local`)

- Dashboard: health, token spend, active pods, activity feed
- Tenant management: vault, MCP toggles, token budgets, usage charts
- Team management: create teams, assign members, provision PVCs
- Settings: IAM users, team vault, MCP server rack (command/args/url), skill browser
- Sessions: list, inspect, invalidate, kill, **Reload Config** (live credential push)
- IAM: invite flow, RBAC (admin / team_lead / user)

**Data, Storage & Skills**

- Local `gtd.db` (SQLite) per agent pod for durable GTD task tracking
- Tiered Skill Architecture:  Separates core system workflows and shared global capabilities from fully isolated, per-channel environments, enabling secure, highly customized skill deployment without cross-contamination.
- Team-shared dynamic PersistentVolumeClaims (`subPath` mounts) for private agent state
- Native Skill Repositories loaded seamlessly from folder mappings

**Routing & Observability**

- **Intelligent Notifications:** Automated dispatch and worker routing via Agent Teams
- **Log Streaming:** Real-time cluster logging and observability via the K8s Watch API
- **Strict Security:** Fully hardened against vulnerability chains (npm audits, lock files, Dependabot)
- **Node 22 Baseline:** Entire platform runs on strict Node 22 LTS engines

**Scheduled Tasks**

- Agent uses `ScheduleTask` MCP tool to persist tasks to disk
- UI Task scheduling and Management via team Virtual employee
- `/loop` command working end-to-end

---

## Setting up slack 

#### Go to the [Slack API Portal](https://api.slack.com/apps?new_app=1).

- Click **Create New App** and select **From scratch**.
- Enter your app name (we suggest **G-eves** but you can use any name) and select your target Slack workspace.
- Click **Create App**. 

- Get the app Token starts with xapp-???????????? and keep it for latter. 

- Scroll back up and click **Install to Workspace**, then authorize the app.
- Goto Oauth & Permission on the right side under Features
- Copy your **Bot User OAuth Token** (`xoxb-...`) and keep it secret.
- Now on the right click the App Manifest to configure your apps behavior. 

- Apply the following app manifest to your Slack application. Update the name fields if you chose a different name.

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

Before you begin, collect:

- **LLM provider credentials** — one of: AWS Access Key ID + Secret + Region (Bedrock), Anthropic API key, or OpenRouter API key
- **Slack tokens** — Bot Token (`xoxb-…`) and App Token (`xapp-…`)
- **Brave Search API key**
- **OpenAI API key** — optional, required for Whisper voice transcription
- **Admin email and display name** — for the Admin UI login

The installer (`kclaw-installer.tar.gz`) is included in this repository. Extract and run it on your target server:

```bash
# Clone the repo
git clone https://github.com/info-struct/kclaw
cd kclaw

# Extract the installer
tar -xvf kclaw-installer.tar.gz
cd kubeclaw-installer

# Run the interactive installer as root
sudo ./scripts/install.sh
```

The installer will prompt for your credentials and automatically provision k3s, Helm, LiteLLM, PostgreSQL, and all KClaw components.

**Verify the installer tarball before running it:**
```bash
md5sum -c ../md5sum-kclaw-installer.gz.txt
```

## UI access and setup

When the installer completes, it writes an `install-summary.txt` file in the installer directory. This file contains all generated secrets, your admin credentials, and internal service URLs. **Keep this file secure and do not commit it** — it is automatically added to `.gitignore`.

```
ADMIN_UI_URL=http://<your-node-ip>
ADMIN_EMAIL=you@example.com
ADMIN_TEMP_PASSWORD=<generated>
LITELLM_MASTER_KEY=<generated>
...
```

For external access, expose the Admin UI (port 3003) using one of:
- **Cloudflare Tunnel** (recommended): https://developers.cloudflare.com/tunnel/setup/
- **Traefik ingress with TLS**: https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress/#tls

Change your admin password on first login.



## K-Claw Team Setup Guide

This guide covers how to set up Teams in the K-Claw Admin UI. Teams allow you to group tenants (users/bots), manage shared MCP servers, and configure team-level variables. K-Claw can automatically provision underlying Kubernetes Persistent Volume Claims (PVCs) for team-wide storage sharding.

#### Creating a Team

1. #### Navigate to the **Teams** section in the K-Claw Admin UI (`/admin/teams`).

2. Click the **+ Create Team** button in the top right.

3. Fill out the team details:

   - **Team Name:** The human-readable name of the team (e.g., `Engineering` or `Marketing`).
   - **Identifier:** The system identifier for the team. This must be lowercase letters, numbers, and hyphens only (e.g., `engineering`). This is used for internal routing and storage paths.
   - **Provision Kubernetes PVC:** Ensure this checkbox is checked (it is checked by default). This triggers the cluster to provision a dedicated Persistent Volume Claim for this team's isolated storage.

4. Click **Create Team**.

### Post-Creation Notes

- If the team is created successfully but the PVC fails to provision immediately (e.g., due to cluster resource limits), you will receive a "PVC warning". The team will still be created, but you may need to check the Kubernetes cluster events to resolve the storage binding.

- Once created, you can click **Manage →** next to the team in the list to configure shared MCP servers and Config Keys for the team.

  

## K-Claw User Provisioning Guide

This guide explains how to invite and provision new users (and their associated agent tenants) using the K-Claw Admin UI Wizard.

#### The Add User Wizard

To onboard a new user, navigate to the **Settings** or **Users** area of the Admin UI and click to open the **Add User Wizard**. 

The provisioning process handles Identity, Tenant (Bot) assignment, Provider setup, and Invite link generation in one streamlined flow.

#### Step 1: User Details

- **Name (optional):** The real name of the invitee (e.g., `Alice Smith`).
- **Email (optional):** Entering the user's email allows K-Claw to automatically attempt to link their Slack identity if they will be using the Slack integration.
- **Role:** Select `User`, `Team Lead`, or `Admin`.
- **Expires In:** Choose how long the invite link will remain valid (1, 7, or 30 days).
- **Platform:** Choose the user's primary interface platform (`Any / Not specified`, `Telegram`, or `Slack`).

#### Step 2: Assign a Bot / Tenant

You must decide how this user will interact with the system:

- **No tenant:** Select this if creating an Admin or Observer account that doesn't need its own agent bot. (Skips to Step 5)
- **Assign to an existing tenant:** Select this to grant the user access to a bot/tenant that is already running in the cluster. You will be prompted to select the tenant from a dropdown. (Skips to Step 5)
- **Create a new tenant for this user:** Select this to provision a brand new agent bot specifically for this user. (Proceeds to Step 3)

#### Step 3: Tenant Details (New Tenant Only)

- **Bot / tenant name:** A friendly name for the agent (e.g., `Alice's Bot`).
- **Identifier:** A URL-safe slug generated from the name (e.g., `alices-bot`). Used for internal routing and storage paths.
- **Team (optional):** Assign the new tenant to a pre-existing Team (see `team-setup.md`). This grants the agent access to the team's shared PVC storage and MCP servers.

#### Step 4: Model Provider (New Tenant Only)

Configure the LLM provider for the new tenant. K-Claw provides presets to speed this up:

- **Provider:** Choose between `LiteLLM (cluster proxy)` or `Anthropic (direct)`. 
  - *Note: LiteLLM is the recommended default for cluster environments.*
- **Model ID:** Defaults to `claude-sonnet-4-6`.
- **Base URL:** If using LiteLLM, this defaults to the cluster-internal service URL (e.g., `http://litellm-service.default.svc.cluster.local:4000`).
- **API Key:** Enter the provider API key (or LiteLLM proxy key). If you have system defaults configured, this will pre-populate.

#### Step 5: Review & Send

1. Review the summary of the invite, tenant assignment, and provider config.
2. Click **Create & Send Invite**. 
3. The system will provision the tenant in the Kubernetes cluster, configure the provider, and generate a unique invite link.
4. Copy the generated invite link and send it to the user. Once they click it, their messaging platform will be linked to the newly provisioned tenant.

## License

**KClaw FSL-1.1-ALv2**

- Free for personal and small business use (up to 30 agents/tenents)
- No selling, leasing, or sub-licensing as a standalone product
- Enterprise license required for >30 tenants or commercial SaaS use

See [LICENSE](https://github.com/info-struct/kclaw/blob/main/LICENSE.md) for full terms.
