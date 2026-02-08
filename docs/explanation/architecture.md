---
title: Architecture
tags:
  - explanation
  - architecture
---

# Architecture Overview

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How all the BlumeOps pieces fit together.

## Physical Layer

Two always-on devices form the infrastructure backbone:

```
┌─────────────────┐     ┌─────────────────┐
│     Indri       │     │     Sifaka      │
│  Mac Mini M1    │────▶│  Synology NAS   │
│  (compute)      │     │  (storage)      │
└─────────────────┘     └─────────────────┘
        │
        │ Tailscale
        ▼
┌─────────────────┐
│    Gilbert      │
│  MacBook Air    │
│  (workstation)  │
└─────────────────┘
```

- **[[indri]]** runs all services (native and containerized)
- **[[sifaka]]** provides bulk storage and backup targets
- **[[gilbert]]** is the development workstation

## Network Layer

[[tailscale]] provides the network fabric:

- All devices on tailnet `tail8d86e.ts.net`
- ACLs control access between devices and services
- MagicDNS provides `*.tail8d86e.ts.net` hostnames
- No port forwarding or public IPs needed

## Service Routing

Two DNS domains route to services:

| Domain | Mechanism | Reachable from |
|--------|-----------|----------------|
| `*.ops.eblu.me` | Caddy reverse proxy on indri | Everywhere (k8s pods, containers, tailnet) |
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | Tailnet clients only |

See [[routing]] for details on when to use which.

## Compute Layer

Services run in two places:

### Native on Indri (Ansible)

Some services run directly on macOS:
- [[forgejo]] - Git forge (needs filesystem access)
- [[zot]] - Container registry (k8s depends on it)
- [[jellyfin]] - Media server (needs VideoToolbox hardware transcoding)
- [[borgmatic]] - Backups (needs host filesystem access)

Managed via Ansible roles in `ansible/roles/`.

### Kubernetes (ArgoCD)

Most services run in minikube on indri:
- [[grafana]], [[prometheus]], [[loki]] - Observability
- [[miniflux]], [[navidrome]], [[kiwix]] - Applications
- [[postgresql]] - Shared database (CloudNativePG)

Managed via ArgoCD from `argocd/manifests/`.

## Data Flow

```
┌──────────────┐
│   Git Repo   │
│  (Forgejo)   │
└──────┬───────┘
       │ push
       ▼
┌──────────────┐     ┌──────────────┐
│   ArgoCD     │────▶│  Kubernetes  │
│  (watches)   │sync │   (runs)     │
└──────────────┘     └──────────────┘
                            │
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Service    │     │   Service    │     │   Service    │
└──────────────┘     └──────────────┘     └──────────────┘
```

1. Code pushed to [[forgejo]]
2. [[argocd]] detects changes (or manual sync triggered)
3. ArgoCD applies manifests to cluster
4. Services start/update in Kubernetes

## Observability

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Alloy     │────▶│ Prometheus  │────▶│   Grafana   │
│ (collector) │     │  (metrics)  │     │ (dashboards)│
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       ▲
       │            ┌─────────────┐            │
       └───────────▶│    Loki     │────────────┘
                    │   (logs)    │
                    └─────────────┘
```

[[alloy]] runs in two places:
- On indri: collects host metrics and logs
- In k8s: collects pod logs and service probes

See [[observability]] for details.

## Secrets Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  1Password  │────▶│  1Password  │────▶│   External  │
│   (vault)   │     │   Connect   │     │   Secrets   │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  K8s Secret │
                                        └─────────────┘
```

Secrets live in 1Password and flow to Kubernetes via [[external-secrets]].

For Ansible, secrets are fetched via `op` CLI in playbook pre_tasks.

## Related

- [[why-gitops]] - Philosophy behind this approach
- [[security-model]] - Access control and secrets
- [[routing]] - Service routing details
