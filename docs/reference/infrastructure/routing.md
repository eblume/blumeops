---
title: Service Routing
tags:
  - infrastructure
  - network
---

# Service Routing

Services are accessible via two DNS domains with different reachability.

## DNS Domains

| Domain | Proxy | Reachable From |
|--------|-------|----------------|
| `*.ops.eblu.me` | Caddy on indri | k8s pods, docker containers, tailnet clients |
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | Tailnet clients only |

**Use `*.ops.eblu.me`** for services that need pod-to-service communication.

## Caddy Services (`*.ops.eblu.me`)

DNS points to indri's Tailscale IP (100.98.163.89). TLS via Let's Encrypt (ACME DNS-01 with Gandi).

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | https://go.ops.eblu.me | Service dashboard |
| [[Forgejo]] | https://forge.ops.eblu.me | Git hosting (SSH: 2222) |
| [[Zot]] | https://registry.ops.eblu.me | Container registry |
| [[Grafana]] | https://grafana.ops.eblu.me | Dashboards |
| [[ArgoCD]] | https://argocd.ops.eblu.me | GitOps CD |
| [[Prometheus]] | https://prometheus.ops.eblu.me | Metrics |
| [[Loki]] | https://loki.ops.eblu.me | Logs |
| [[Miniflux]] | https://feed.ops.eblu.me | RSS reader |
| [[Kiwix]] | https://kiwix.ops.eblu.me | Offline Wikipedia |
| [[Transmission]] | https://torrent.ops.eblu.me | BitTorrent |
| [[TeslaMate]] | https://tesla.ops.eblu.me | Tesla logger |
| [[Navidrome]] | https://dj.ops.eblu.me | Music streaming |
| [[Jellyfin]] | https://jellyfin.ops.eblu.me | Media server |
| [[PostgreSQL]] | pg.ops.eblu.me:5432 | Database |
| [[Sifaka NAS|Sifaka]] | https://nas.ops.eblu.me | NAS dashboard |

## Tailscale-Only Services

| Service | URL | Description |
|---------|-----|-------------|
| Kubernetes | https://k8s.tail8d86e.ts.net | Minikube API |

## Port Map (Indri)

| Port | Service | Protocol | Binding | Notes |
|------|---------|----------|---------|-------|
| 443 | Caddy | HTTPS | 0.0.0.0 | Reverse proxy |
| 2222 | Caddy L4 | TCP | 0.0.0.0 | SSH proxy to Forgejo |
| 5432 | Caddy L4 | TCP | 0.0.0.0 | PostgreSQL proxy |
| 2200 | Forgejo SSH | TCP | localhost | Built-in SSH server |
| 3001 | Forgejo | HTTP | localhost | Web UI |
| 5050 | Zot | HTTP | localhost | Registry API |
| 8096 | Jellyfin | HTTP | localhost | Media server |
| 44491 | K8s API | HTTPS | 0.0.0.0 | Minikube API server |

## Related

- [[Tailscale]] - ACL configuration
- [[Indri]] - Where services run
