---
title: Architecture
modified: 2026-09-04
last-reviewed: 2026-09-04
tags:
  - explanation
  - architecture
---

# Architecture Overview

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How all the BlumeOps pieces fit together.

## Physical Layer

Three always-on devices form the infrastructure backbone:

```
┌─────────────────┐     ┌─────────────────┐
│     Indri       │     │     Sifaka      │
│  Mac Mini M1    │────▶│  Synology NAS   │
│  (compute)      │     │  (storage)      │
└─────────────────┘     └─────────────────┘
        │                       ▲
        │ Tailscale             │ NFS
        │               ┌──────┴──────────┐
        │               │    Ringtail     │
        │               │  NixOS PC      │
        │               │  (GPU compute) │
        │               └─────────────────┘
        ▼
┌─────────────────┐
│    Gilbert      │
│  MacBook Air    │
│  (workstation)  │
└─────────────────┘
```

- **[[indri]]** runs most services (native and containerized)
- **[[ringtail]]** runs GPU workloads (Frigate NVR) and related services (ntfy)
- **[[sifaka]]** provides bulk storage and backup targets
- **[[gilbert]]** is the development workstation

## Network Layer

[[tailscale]] provides the network fabric. All devices join a single tailnet (`tail8d86e.ts.net`) connected via WireGuard tunnels — no port forwarding or public IPs on homelab devices. ACLs control which devices and services can talk to each other, and MagicDNS provides `*.tail8d86e.ts.net` hostnames.

## Routing Layer

Three layers of reverse proxying expose services at different scopes:

| Domain | Proxy | Reachable from |
|--------|-------|----------------|
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | Tailnet clients only |
| `*.ops.eblu.me` | [[caddy]] on indri | k8s pods, containers, tailnet clients |
| `*.eblu.me` | [[flyio-proxy]] on Fly.io | Public internet |

**Tailscale** is the base layer — every service gets a MagicDNS hostname. The [[tailscale-operator]] gives Kubernetes services their own Tailscale Ingress endpoints.

**[[caddy]]** runs natively on [[indri]] and provides a unified `*.ops.eblu.me` wildcard with TLS (Let's Encrypt via DNS-01/Gandi). It proxies to both local services (Forgejo, Zot, Jellyfin) and Kubernetes services (via their Tailscale Ingress endpoints). Caddy serves both tailnet clients and public traffic (via the Fly proxy).

**[[flyio-proxy]]** runs on Fly.io for select services that need public internet access. Traffic hits Fly.io's Anycast edge, terminates TLS, and tunnels back to Caddy on indri over a direct Tailscale WireGuard connection. The proxy uses `tag:flyio-target` ACLs — indri carries this tag so the proxy can reach Caddy, but cannot route to arbitrary services on the tailnet.

See [[routing]] for the full service URL table and port map.

## Compute Layer

Services run across two compute targets:

**Native on indri (Ansible)** — services that need host-level access run directly on macOS, managed via Ansible roles in `ansible/roles/`. See [[indri]] for the full list.

**K3s on ringtail (ArgoCD)** — all Kubernetes workloads, including ArgoCD itself, run on [[ringtail]]'s single-node k3s cluster, managed from `argocd/manifests/`. See [[apps]] for the application registry. GPU workloads (Frigate NVR object detection, Ollama) use the RTX 4080. (Until 2026-06 most services ran in minikube on indri — see [[retire-minikube]].)

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

The stack is Grafana + Prometheus (metrics), Loki (logs), and Tempo (traces),
with Alloy collecting all three signals.

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Alloy     │────▶│ Prometheus  │────▶│   Grafana   │
│ (metrics)   │     │  (metrics)  │     │ (dashboards)│
└─────────────┘     └─────────────┘     ▲             │
       │                                 │             │
       ├──────────▶┌─────────────┐       │             │
       │           │    Loki     │───────┘             │
       │           │   (logs)    │                     │
       │           └─────────────┘                     │
       │                                                │
       └──────────▶┌─────────────┐                     │
                   │    Tempo    │─────────────────────┘
                   │   (traces)  │
                   └─────────────┘
```

[[alloy]] collects all three signals:
- On [[indri]] (Ansible): collects host metrics and logs
- In k8s as `alloy-ringtail`: pod logs and service metrics → Prometheus + Loki
- In k8s as `alloy-tracing-ringtail`: traces → Tempo over OTLP
- On [[flyio-proxy]]: tails nginx access logs and derives request metrics

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
