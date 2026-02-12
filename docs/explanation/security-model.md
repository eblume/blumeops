---
title: Security Model
date-modified: 2026-02-11
last-reviewed: 2026-02-11
tags:
  - explanation
  - security
---

# Security Model

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How BlumeOps handles network security, secrets, and access control.

## Network Security: Tailscale

The foundational security decision is using [[tailscale]] as the network layer.

### Zero Trust Networking

BlumeOps infrastructure has no public IP addresses or port forwarding. Most services are only accessible via Tailscale:

- **Encrypted by default** - WireGuard encryption for all traffic
- **Identity-based access** - ACLs based on user/device identity, not IP addresses
- **Minimal public surface** - only selected services are exposed via [[flyio-proxy]]

### Public Access via Fly.io

A small number of services are exposed to the internet through a reverse proxy on Fly.io that tunnels back to the homelab over Tailscale. The proxy uses restricted ACLs (`tag:flyio-target`) so it can only reach explicitly tagged endpoints — a compromised proxy cannot route to arbitrary services on the tailnet. See [[flyio-proxy]] for details and [[expose-service-publicly]] for the security considerations.

### Defense in Depth

Even within the tailnet, access is restricted:

```
Internet ──▶ Fly.io proxy ──▶ tag:flyio-target only (docs, observability)

Tailnet:
  Admin ────────▶ All services
  Member ───────▶ User-facing services only
  Homelab tag ──▶ NAS (for backups)
```

See [[tailscale]] for the full ACL matrix.

### Tailscale Operator Privileges

The [[tailscale-operator]] bridges Kubernetes and the Tailscale control plane. Its Kubernetes RBAC is namespaced to `tailscale` — it can't read secrets or create pods in other namespaces. On the Tailscale side, its OAuth client can create devices, generate auth keys, and assign `tag:k8s` or `tag:flyio-target`. In practice this means anyone who can write Ingress resources to the cluster can expose a service to the tailnet (or publicly, via `tag:flyio-target`), and Tailscale admins can reconfigure how those services are routed. Both are expected parts of normal operations — but be careful about granting write access to either Kubernetes or the Tailscale admin console, since both can change what's exposed.

## Secrets Management

Secrets follow a hierarchy:

### Source of Truth: 1Password

All secrets originate in 1Password's `blumeops` vault:
- API keys, tokens, passwords
- SSH keys and certificates
- OAuth credentials

### Kubernetes: External Secrets Operator

[[external-secrets]] syncs secrets from 1Password to Kubernetes:

```
1Password ──▶ 1Password Connect ──▶ ExternalSecret ──▶ K8s Secret
```

Services reference native Kubernetes Secrets; they don't know about 1Password.

### Ansible: op CLI

Ansible playbooks fetch secrets at runtime via `op read`:

```yaml
- name: Fetch secret
  ansible.builtin.command:
    cmd: op read "op://vault/item/field"
  delegate_to: localhost
```

Always use `op read` — never `op item get --fields`, which corrupts multi-line values by wrapping them in quotes. Secrets are held in memory as Ansible facts, never written to disk.

### Git Repository

The repository is public. Secrets must never be committed:
- `.gitignore` excludes sensitive patterns
- Pre-commit hooks scan for potential secrets (TruffleHog)
- All config files use references to secrets, not values

## Access Control Philosophy

### Principle of Least Privilege

Services and devices get minimum necessary access:

| Entity | Access |
|--------|--------|
| Admin users | Everything |
| Member users | User-facing services only |
| Homelab servers | Only what they need (NAS for backups) |
| K8s pods | No Tailscale access (use Caddy proxy) |

### Tagged Devices vs User Devices

Important Tailscale concept:
- **User devices** (like gilbert) have user identity and inherit user ACLs
- **Tagged devices** (like indri with `tag:homelab`) lose user identity

Don't tag user devices - it breaks user-based access rules.

## Authentication Patterns

### Service-to-Service

Internal services use:
- Kubernetes service discovery (no auth needed within cluster)
- Tailscale identity for cross-host communication

### User-to-Service

Users authenticate via:
- Service-specific credentials (stored in 1Password)
- Some services support Tailscale identity (future)

### AI/Automation Access

Claude Code and automation use:
- SSH keys for git operations
- ArgoCD tokens for deployments
- 1Password CLI for secret retrieval (requires user approval)

## What's Not Protected

Honest assessment of security boundaries:

- **Local network attacks** - If someone is on your home WiFi, they could potentially access the NAS directly
- **Physical access** - No disk encryption on servers (trade-off for reliability)
- **Supply chain** - Container images from upstream registries
- **Operator error** - Misconfigured ACLs or leaked credentials

The model assumes a trusted home network and focuses on protecting against internet-based attacks.

## Related

- [[tailscale]] - ACL configuration
- [[1password]] - Secrets management
- [[external-secrets]] - Kubernetes secrets
- [[architecture]] - Overall system design
