---
title: Security Model
modified: 2026-09-05
last-reviewed: 2026-09-05
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

The homelab hosts have no public IP addresses or port forwarding — most services are only accessible via Tailscale (the sole forwarded port is the Fly.io proxy's own WireGuard listener, UDP 41641).

- **Encrypted by default** - WireGuard encryption for all traffic
- **Identity-based access** - ACLs based on user/device identity, not IP addresses
- **Minimal public surface** - only selected services are exposed via [[flyio-proxy]]

### Public Access via Fly.io

A small number of services are exposed to the internet through a reverse proxy on Fly.io that tunnels back to the homelab over Tailscale. The proxy uses restricted ACLs (`tag:flyio-target`) so it can only reach explicitly tagged endpoints — a compromised proxy cannot route to arbitrary services on the tailnet. The forge frontend sits behind Anubis proof-of-work. Observability (Grafana, Loki, Prometheus) is tailnet-only and never public. See [[flyio-proxy]] for the exposed-services list and [[expose-service-publicly]] for the security considerations.

### Defense in Depth

Even within the tailnet, access is restricted:

```
Internet ──▶ Fly.io proxy ──▶ tag:flyio-target only (docs, cv, forge, shower, photos)

Tailnet:
  Admin ────────▶ All services
  Member ───────▶ User-facing services only
  Homelab tag ──▶ NAS (for backups)
```

See [[tailscale]] for the full ACL matrix.

### Tailscale Operator Privileges

The [[tailscale-operator]] bridges Kubernetes and the Tailscale control plane. Its in-namespace `Role` covers secrets, service accounts, configmaps, and pod status in the `tailscale` namespace only; it additionally holds a `ClusterRole` over cluster-wide Services and Ingresses, which the ProxyGroup tailnet-VIP model needs. On the Tailscale side, its tag-owner identity may assign `tag:k8s`, `tag:flyio-target`, and `tag:agent`. In practice this means anyone who can write Ingress resources to the cluster can expose a service to the tailnet (or publicly, via `tag:flyio-target`), and Tailscale admins can reconfigure how those services are routed. Both are expected parts of normal operations — but be careful about granting write access to either Kubernetes or the Tailscale admin console, since both can change what's exposed.

## Secrets Management

Secrets follow a hierarchy:

### Source of Truth: 1Password

All secrets originate in 1Password, split across three vaults:
- `blumeops` — infrastructure secrets (API keys, tokens, SSH keys, OAuth credentials), served to Kubernetes via Connect and read by ansible
- `blumeops-ci` — Forgejo CI job credentials, read at run time by workflows
- `agents` — talos pod credentials (service-account token, Forgejo bot token, read-only ArgoCD credential)

1Password Connect is provisioned `--vaults blumeops` and the CI service account reads only `blumeops-ci` — neither scope can be widened from its consumer, so a compromised pod or CI job can't reach the others.

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
- Gitleaks scans the full git history as a CI job on every PR; prek hooks additionally run `detect-private-key` locally
- All config files use references to secrets, not values

## Access Control Philosophy

### Principle of Least Privilege

Services and devices get minimum necessary access:

| Entity | Access |
|--------|--------|
| Admin users | Everything |
| Member users | User-facing services only |
| Homelab servers | Only what they need (NAS for backups) |
| K8s services | Tailnet VIP via `tag:k8s` Ingress pods (ProxyGroup) |
| Agent (talos) pods | No direct tailnet access — egress only via the egress-gateway pod |

### Tagged Devices vs User Devices

Important Tailscale concept:
- **User devices** (like gilbert) have user identity and inherit user ACLs
- **Tagged devices** (like indri with `tag:homelab`) lose user identity

Don't tag user devices - it breaks user-based access rules.

The talos agent pods sit behind a deny-by-default NetworkPolicy: their only egress path is the egress-gateway pod, which joins the tailnet as `tag:agent` — granted a small fixed set of indri ports, nothing more. See [[agent-containerization]].

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

The talos agent service ([[agent-containerization]]) runs pi sessions with deliberately scoped access:
- Git — commits and pushes as the `agents` Forgejo bot, which is read-only on canonical repos; agent-authored changes go out as cross-repo PRs from its fork
- Deployments — no ArgoCD tokens in the pod; the `argocd` CLI is a read-only account. Any deploy is a warrant request-run that a human approves ([[warrant-approval-gated-runs]])
- 1Password — a service-account token scoped to the `agents` vault only, injected into the pod; no interactive approval, and the `blumeops`/`blumeops-ci` vaults are unreachable
- Network — all egress transits the egress-gateway pod, which is per-connection logged; the pod itself is fenced by deny-by-default policy

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
