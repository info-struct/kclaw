# KClaw

**Kubernetes-native assistant.** Persistent agent pods, centralized credential management, multi-tenant IAM, and a full web admin UI.

Running in production on k3s (PicoCluster, ARM). 
---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (openclaw namespace)                  │
│                                                           │
│  ┌─────────────────┐   ┌─────────────────────────────┐   │
│  │  KClaw Admin UI │   │  Orchestrator               │   │
│  │  (kclaw-admin-  │   │  - Channels (Slack, Telegram)│   │
│  │   ui.local)     │   │  - Message routing          │   │
│  │  - Dashboard    │   │  - Pod lifecycle management │   │
│  │  - IAM / RBAC   │   │  - Task scheduler + CronJob │   │
│  │  - Tenants      │   │  - Admin API (port 3002)    │   │
│  │  - Teams        │   └────────────┬────────────────┘   │
│  │  - MCP servers  │                │ HTTP POST /message  │
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
│  │  - Team config  │   External: api.anthropic.com       │
│  │  - MCP configs  │                                     │
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

## What's Working

**Messaging**
- Slack and Telegram channels
- Persistent agent pods — session context kept in memory across messages
- First message: ~21s (pod creation + startup). Subsequent: ~3–5s

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

## Quick Start

See **[specs/FIRST_INSTALL.md](specs/FIRST_INSTALL.md)** for the full step-by-step guide.

Short version:

```bash
# 1. Namespace + registry secret
kubectl create namespace openclaw
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n openclaw

# 2. Generate secrets
ENCRYPTION_KEY=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 48)
ADMIN_TOKEN=$(openssl rand -hex 32)

kubectl create secret generic credrouter-secrets \
  -n openclaw \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --from-literal=jwt-secret="$JWT_SECRET"

kubectl create secret generic kclaw-admin-ui-secrets \
  -n openclaw \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=credrouter-admin-token="$ADMIN_TOKEN"

# 3. Deploy
sudo docker build -t gryanfawcett/kubeclaw-credrouter:latest ./src/credrouter && \
  sudo docker push gryanfawcett/kubeclaw-credrouter:latest
kubectl apply -k k8s/credrouter/

kubectl apply -f k8s/service-account.yaml
kubectl apply -f k8s/kubeclaw-orchestrator.yaml

sudo docker build -t gryanfawcett/kclaw-admin-ui:latest ./admin-ui && \
  sudo docker push gryanfawcett/kclaw-admin-ui:latest
kubectl apply -f k8s/admin-ui/

# 4. Ensure agent image is set on orchestrator
kubectl set env deployment/kubeclaw-orchestrator -n openclaw \
  CONTAINER_IMAGE=gryanfawcett/kubeclaw-agent:latest

# 5. Bootstrap first admin
kubectl port-forward -n openclaw svc/credrouter 8080:80 &
ADMIN_TOKEN=$(kubectl get secret kclaw-admin-ui-secrets -n openclaw \
  -o jsonpath='{.data.credrouter-admin-token}' | base64 -d)
echo "y" | CREDROUTER_URL=http://127.0.0.1:8080 CREDROUTER_ADMIN_TOKEN=$ADMIN_TOKEN \
  npx tsx src/admin/cli.ts iam bootstrap your@email.com --name "Your Name"
kill %1

# 6. /etc/hosts
echo "<node-ip> kclaw-admin-ui.local kubeclaw-admin.local" | sudo tee -a /etc/hosts
```

Open `http://kclaw-admin-ui.local` and log in with the bootstrapped credentials.

---

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

## Rebuilding After Code Changes

```bash
# CredRouter
sudo docker build -t gryanfawcett/kubeclaw-credrouter:latest ./src/credrouter
sudo docker push gryanfawcett/kubeclaw-credrouter:latest
kubectl rollout restart deployment/credrouter -n openclaw

# Admin UI
sudo docker build -t gryanfawcett/kclaw-admin-ui:latest ./admin-ui
sudo docker push gryanfawcett/kclaw-admin-ui:latest
kubectl rollout restart deployment/kclaw-admin-ui -n openclaw

# Orchestrator
./build-orchestrator.sh
sudo docker push gryanfawcett/kubeclaw-orchestrator:latest
kubectl rollout restart deployment/kubeclaw-orchestrator -n openclaw

# Agent
cd container && ./build.sh
sudo docker tag kubeclaw-agent:latest gryanfawcett/kubeclaw-agent:latest
sudo docker push gryanfawcett/kubeclaw-agent:latest
kubectl delete pods -n openclaw -l app=kubeclaw-agent  # recreated on next message
```

---

## Documentation

| Document | Purpose |
|----------|---------|
| [specs/FIRST_INSTALL.md](specs/FIRST_INSTALL.md) | Full step-by-step first install |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Current deployment status + common issues |
| [docs/ADMIN_README.md](docs/ADMIN_README.md) | Admin API & CLI: setup, commands, operations |
| [admin-ui/SETUP.md](admin-ui/SETUP.md) | Admin UI gotchas and local dev |
| [docs/CREDROUTER.md](docs/CREDROUTER.md) | CredRouter architecture & API reference |
| [docs/LITELLM.md](docs/LITELLM.md) | LiteLLM proxy: model routing, virtual keys |
| [docs/MCP_OAUTH_GUIDE.md](docs/MCP_OAUTH_GUIDE.md) | Adding OAuth-backed MCP servers end-to-end |
| [BUILD_CONTAINERS.md](BUILD_CONTAINERS.md) | Building agent and orchestrator images |

---

## Requirements

- Kubernetes 1.24+ (tested on k3s on ARM)
- Namespace: `openclaw`
- Orchestrator node selector: `kubernetes.io/hostname` (agents pin to same node for hostPath access)
- Agent pods run as UID 1000 (Claude CLI refuses `--dangerously-skip-permissions` as root)

---

## License

**KubeClaw Community License v1.0**

- Free for personal and small business use (up to 10 tenants)
- No selling, leasing, or sub-licensing as a standalone product
- Enterprise license required for >10 tenants or commercial SaaS use

See [LICENSE](LICENSE) for full terms.
