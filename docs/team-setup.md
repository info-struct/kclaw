# Team Shared Storage & Skills

This guide explains how KClaw's team-scoped storage and shared skills work, and how to set them up.

---

## Overview

Every team in KClaw gets a dedicated Kubernetes PersistentVolumeClaim (PVC). That PVC is mounted into every agent pod on the team at `/workspace/shared`, giving all team members a shared read/write filesystem. Team skills are discovered automatically from a subdirectory of that shared volume.

---

## Storage: One PVC per Team

When you create a team in the Admin UI, KClaw provisions a PVC named:

```
kclaw-team-pvc-{identifier}
```

For example, a team with identifier `engineering` gets `kclaw-team-pvc-engineering`.

This PVC is mounted into every agent pod on that team at:

```
/workspace/shared
```

Any file a team member's agent writes to `/workspace/shared` is immediately visible to all other agents on the same team.

---

## Team Skills

### Directory Layout

Team skills live inside the team PVC under:

```
/workspace/shared/skills/{skill-name}/
```

Each skill directory must contain a `CLAUDE.md` file. That is all KClaw requires. At agent startup, the runner scans `/workspace/shared/skills/`, finds every subdirectory, and passes them to the Claude SDK as `additionalDirectories`. The SDK auto-loads each `CLAUDE.md` into the agent's context.

**Example layout:**

```
/workspace/shared/
└── skills/
    ├── sop-customer-support/
    │   ├── CLAUDE.md          ← team SOP loaded by every agent on the team
    │   └── templates/
    │       └── reply.md
    └── research-workflow/
        └── CLAUDE.md          ← shared research process
```

### What Goes in CLAUDE.md

Write the skill as you would any Claude Code skill — instructions, workflows, constraints, or SOPs. The SDK loads it as an additional context directory, so it behaves identically to a built-in skill. Any supporting files (templates, reference docs) can sit alongside the `CLAUDE.md` and referenced from within it.

---

## Skill Layers

KClaw loads skills from three layers simultaneously. There is no override — all layers are active at the same time.

| Layer | Mount Path | Managed By | Scope |
|-------|-----------|------------|-------|
| Built-in | `/app/skills/` (baked into image) | IT / DevOps | All agents globally |
| Global | `/workspace/global/` (host path) | IT / Admin | All agents globally |
| Team | `/workspace/shared/skills/` (team PVC) | Team Lead | Team members only |

---

## How to Add a Team Skill

1. Write your skill directory into the team PVC at `/workspace/shared/skills/my-skill/CLAUDE.md` — use the Admin UI PVC browser or copy files directly via `kubectl cp`.
2. The skill is picked up automatically on the next message each team member's agent receives. No pod restart is required — the skills directory is scanned on every request.

### Using kubectl cp

```bash
# Copy a local skill directory into the team PVC via a running agent pod
kubectl cp ./my-skill kclaw/<agent-pod-name>:/workspace/shared/skills/my-skill
```

---

## Wiring a User to a Team

1. In the Admin UI navigate to **Tenants** and click **Edit** on the tenant.
2. Set the **Team** field to the target team.
3. On the tenant's next pod startup, CredRouter resolves the team's PVC name and the orchestrator mounts it at `/workspace/shared`.

Alternatively, assign the team during initial user provisioning via the **Add User Wizard** (Step 3: Tenant Details).

---

## Troubleshooting

**Skills not loading**

- Confirm the directory exists at `/workspace/shared/skills/{skill-name}/CLAUDE.md` (not a nested subdirectory).
- Check that the tenant is assigned to the correct team in the Admin UI.
- Verify the team PVC is bound: `kubectl get pvc -n kclaw kclaw-team-pvc-{identifier}`.

**PVC not provisioned**

If the team was created but the PVC failed to bind (cluster resource limits, storage class unavailable), the team record still exists. Check cluster events:

```bash
kubectl describe pvc kclaw-team-pvc-{identifier} -n kclaw
```

Resolve the storage binding, then trigger a re-provision from the Admin UI under **Teams → Manage → Provision PVC**.

**Changes not visible across agents**

The team PVC uses `ReadWriteOnce` access mode. If agents are pinned to different nodes, only the node that holds the PVC binding will be able to mount it. All agents on a team should run on the same node (enforced by the orchestrator node selector in `values.yaml`).
