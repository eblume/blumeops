---
title: Routing
tags:
  - infrastructure
  - networking
---

# Service Routing

Services are accessible via three DNS domains with different reachability.

## DNS Domains

| Domain | Proxy | Reachable From |
|--------|-------|----------------|
| `*.eblu.me` | [[flyio-proxy]] (Fly.io → Tailscale tunnel) | Public internet |
| `*.ops.eblu.me` | Caddy on indri | k8s pods, docker containers, tailnet clients |
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | Tailnet clients only |

**Use `*.ops.eblu.me`** for services that need pod-to-service communication. Use `*.eblu.me` for services exposed publicly via Fly.io.

## Caddy Services (`*.ops.eblu.me`)

DNS points to [[indri]]'s Tailscale IP. TLS via Let's Encrypt (ACME DNS-01 with Gandi).

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | https://go.ops.eblu.me | Service dashboard |
| [[forgejo]] | https://forge.ops.eblu.me | Git hosting (SSH: 2222) |
| [[zot]] | https://registry.ops.eblu.me | Container registry |
| [[grafana]] | https://grafana.ops.eblu.me | Dashboards |
| [[argocd]] | https://argocd.ops.eblu.me | GitOps CD |
| [[prometheus]] | https://prometheus.ops.eblu.me | Metrics |
| [[loki]] | https://loki.ops.eblu.me | Logs |
| [[miniflux]] | https://feed.ops.eblu.me | RSS reader |
| [[kiwix]] | https://kiwix.ops.eblu.me | Offline Wikipedia |
| [[transmission]] | https://torrent.ops.eblu.me | BitTorrent |
| [[teslamate]] | https://tesla.ops.eblu.me | Tesla logger |
| [[navidrome]] | https://dj.ops.eblu.me | Music streaming |
| [[jellyfin]] | https://jellyfin.ops.eblu.me | Media server |
| [[postgresql]] | pg.ops.eblu.me:5432 | Database |
| [[sifaka|Sifaka]] | https://nas.ops.eblu.me | NAS dashboard |

## Public Services (`*.eblu.me`)

DNS CNAMEs point to `blumeops-proxy.fly.dev`. TLS via Fly.io-managed Let's Encrypt. Traffic tunnels back to the homelab over Tailscale. Only services tagged `tag:flyio-target` are reachable by the proxy — see [[flyio-proxy]] for details.

| Service | URL | Description |
|---------|-----|-------------|
| [[docs]] | https://docs.eblu.me | Documentation site |

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

- [[gandi]] - DNS hosting for `eblu.me`
- [[tailscale]] - ACL configuration
- [[indri]] - Where services run
- [[flyio-proxy]] - Public reverse proxy for `*.eblu.me`
- [[expose-service-publicly]] - How to add a new public service
