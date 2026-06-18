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
| `ND_BACKUP_PATH` | /data/backup |
| `ND_BACKUP_SCHEDULE` | `0 1 * * *` (daily 01:00) |
| `ND_BACKUP_COUNT` | 7 |

## Backup

The music *files* live on [[sifaka]] (NFS, read-only) and are backed up there.
Navidrome's **database** — users, play counts, playlists, favorites — lives on
the local `/data` PVC and predated the ringtail migration as a backup gap.

Navidrome's [native backup](https://www.navidrome.org/docs/usage/admin/backup/)
(`ND_BACKUP_*`) writes a consistent SQLite snapshot to
`/data/backup/navidrome_backup_<YYYY.MM.DD_HH.MM.SS>.db` daily at 01:00, keeping the newest 7.
[[borgmatic]] on [[indri]] then ferries the **newest** snapshot off the PVC at
02:00 via its `borgmatic_k8s_file_dumps` hook (ssh to ringtail → `kubectl exec`
`ls`/`cat` → `~/.local/share/borgmatic/k8s-dumps/navidrome.db`), so the DB lands
in the daily Borg archive. This requires `coreutils` in the nix image (for the
in-pod `ls`/`cat`) — see `containers/navidrome/default.nix`.

Force an on-demand snapshot (e.g. to bootstrap before borgmatic's first run):

```fish
ssh eblume@ringtail 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml k3s kubectl -n navidrome exec deploy/navidrome -- navidrome backup create'
```

Restore (offline only — stop navidrome first): `navidrome backup restore --backup-file <path>`.

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
