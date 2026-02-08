---
title: Why GitOps
tags:
  - explanation
  - philosophy
---

# Why GitOps?

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

BlumeOps uses GitOps principles for managing personal infrastructure. This might seem like overkill for a homelab, but there are good reasons.

## The Problem with Manual Infrastructure

Traditional server management involves SSHing into machines and running commands. This works, but creates problems:

- **Drift**: The actual state diverges from what you think it is
- **Amnesia**: You forget what you changed and why
- **Fragility**: One bad command can break things with no easy rollback
- **Bus factor**: Only you know how it works (even AI assistants struggle without context)

## Git as the Source of Truth

GitOps inverts the model: instead of pushing changes to servers, you commit desired state to Git, and automation pulls it into reality.

**Benefits:**
- Every change is tracked with commit history
- Pull requests enable review before deployment
- Rollback is just `git revert`
- The repo *is* the documentation

## Why This Matters for a Homelab

A personal homelab isn't a production environment, but it shares the same challenges:

1. **Memory is unreliable** - Six months from now, you won't remember why you configured Caddy that way
2. **Experimentation is constant** - You try things, break things, want to undo things
3. **AI assistance needs context** - Claude can help much more effectively when it can read your infrastructure as code

## The BlumeOps Approach

BlumeOps uses layered GitOps:

| Layer | Tool | What it manages |
|-------|------|-----------------|
| **Tailnet** | [[tailscale|Pulumi]] | ACLs, tags, DNS |
| **Host config** | [[roles|Ansible]] | Services on [[indri]] |
| **Kubernetes** | [[argocd|ArgoCD]] | Containerized workloads |

Each layer has its own reconciliation loop:
- Pulumi applies on `mise run tailnet-up`
- Ansible applies on `mise run provision-indri`
- ArgoCD watches Git and syncs manually or automatically

## Trade-offs

GitOps isn't free:

- **Learning curve** - You need to understand Ansible, ArgoCD, Pulumi
- **Indirection** - Can't just `apt install` something; need to add it to config
- **Complexity** - More moving parts than a simple server

But for BlumeOps, the trade-off is worth it. The infrastructure is complex enough that managing it imperatively would be error-prone, and the GitOps approach enables effective AI-assisted operations.

## Related

- [[architecture]] - How the pieces fit together
- [[argocd]] - Kubernetes GitOps
- [[roles|Ansible roles]] - Host configuration
