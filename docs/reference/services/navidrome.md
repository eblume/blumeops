---
title: Navidrome
modified: 2026-04-18
last-reviewed: 2026-04-18
tags:
  - service
  - media
---

# Navidrome

Self-hosted music streaming server.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://dj.ops.eblu.me |
| **Tailscale URL** | https://dj.tail8d86e.ts.net |
| **ArgoCD app** | `navidrome` |
| **Sync policy** | Manual |
| **Namespace** | `navidrome` |
| **Manifests** | `argocd/manifests/navidrome/` |
| **Image** | `registry.ops.eblu.me/blumeops/navidrome:v0.61.1-3ecd888` |
| **Tracked upstream version** | `v0.61.1` |

Traffic reaches Navidrome through a Tailscale Ingress at `dj.tail8d86e.ts.net`,
with [[caddy]] proxying `dj.ops.eblu.me` to that tailnet endpoint.

## Storage

| Mount | Type | Source | Access |
|-------|------|--------|--------|
| /music | NFS PV | sifaka:/volume1/music | Read-only |
| /data | Local PVC (10Gi) | minikube storage | Read-write |

The `/data` directory contains SQLite database, configuration, and cache.

## Configuration

| Variable | Value |
|----------|-------|
| `ND_SCANNER_SCHEDULE` | `@every 1h` |
| `ND_LOGLEVEL` | info |
| `ND_MUSICFOLDER` | /music |
| `ND_DATAFOLDER` | /data |

## Runtime

| Property | Value |
|----------|-------|
| **Replicas** | 1 |
| **Container port** | `4533` |
| **Requests** | `100m` CPU, `128Mi` memory |
| **Limits** | `500m` CPU, `512Mi` memory |
| **Security context** | Runs as uid/gid `1000`, `fsGroup: 1000`, `RuntimeDefault` seccomp |
| **Health checks** | Liveness/readiness probe on `GET /ping` |

## Authentication

Local accounts only. Authentik SSO integration was evaluated (Feb 2026) but not pursued — Navidrome lacks native OIDC support. The reverse proxy auth approach (`ND_EXTAUTH_*`) can pass a username header from Authentik, but cannot map Authentik groups to Navidrome admin status, making group-based admin delegation impossible.

## Related

- [[routing]] - URL and exposure model
- [[caddy]] - Reverse proxy from `dj.ops.eblu.me` to the tailnet ingress
- [[sifaka|Sifaka]] - Music storage
- [[jellyfin]] - Video streaming
- [[service-versions]] - Tracked upstream version inventory
