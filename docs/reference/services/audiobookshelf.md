---
title: Audiobookshelf
modified: 2026-09-16
last-reviewed: 2026-09-16
tags:
  - service
  - media
---

# Audiobookshelf

Self-hosted audiobook streaming server.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://audiobooks.ops.eblu.me |
| **Tailscale URL** | https://audiobooks.tail8d86e.ts.net |
| **ArgoCD app** | `audiobookshelf-ringtail` |
| **Sync policy** | Automated |
| **Namespace** | `audiobookshelf` |
| **Manifests** | `argocd/manifests/audiobookshelf-ringtail/` |
| **Image** | `registry.ops.eblu.me/blumeops/audiobookshelf` (nix-built, see `containers/audiobookshelf/default.nix`) |
| **Tracked upstream version** | `v2.36.0` |

Traffic reaches Audiobookshelf through a Tailscale Ingress at
`audiobooks.tail8d86e.ts.net`, with [[caddy]] proxying `audiobooks.ops.eblu.me` to
that tailnet endpoint. The first visit is the setup page, where the admin
user is created.

## Storage

| Mount | Type | Source | Access |
|-------|------|--------|--------|
| /music | NFS PV | sifaka:/volume1/music/Audiobooks | Read-only |
| /config | Local PVC (10Gi) | k3s local-path storage | Read-write |
| /metadata | Local PVC (10Gi) | k3s local-path storage | Read-write |

The `/config` directory holds the SQLite database and configuration;
`/metadata` holds covers, metadata and reading progress. Both mounts share
the same `audiobookshelf-data` PVC.

## Library

Audio files live on [[sifaka]] at `/volume1/music/Audiobooks`
(`Author/[Series/]Title` layout), mounted read-only at `/music`, with the
library pointed at `/music/Audiobooks`. The `Audiobooks/` folder carries a
`.ndignore` marker so [[navidrome]] skips it — that marker is the
cohabitation contract between the two servers on the same share. See
[[rip-a-disc]] for how rips land there.

## Backup

Audiobookshelf's built-in scheduled backup zips config + metadata to
`/metadata/backups/<YYYY-MM-DD[T]HHmm>.audiobookshelf` (fixed-width
timestamp, so lexically sortable). [[borgmatic]] on [[indri]] ferries the
newest snapshot off the PVC via its `borgmatic_k8s_file_dumps` hook (ssh to
ringtail → `kubectl exec` `ls`/`cat` →
`~/.local/share/borgmatic/k8s-dumps/audiobookshelf.db`), landing it in the
daily Borg archive — see the [[backups]] Databases table.

The audio *files* themselves are not backed up: they live on [[sifaka]]
(RAID-5 only), the same policy as the rest of the music share.

## Runtime

| Property | Value |
|----------|-------|
| **Replicas** | 1 |
| **Container port** | `80` |
| **Requests** | `100m` CPU, `128Mi` memory |
| **Limits** | `500m` CPU, `512Mi` memory |
| **Security context** | Runs as uid/gid `1000`, `fsGroup: 1000`, `RuntimeDefault` seccomp |
| **Health checks** | Liveness/readiness probe on `GET /healthcheck` |

Only `TZ` is set — the nix image's entrypoint wrapper hardcodes the port
and overrides `PORT`/`CONFIG_PATH`/`METADATA_PATH`, so the deployment sets
none of those.

## Related

- [[routing]] - URL and exposure model
- [[caddy]] - Reverse proxy from `audiobooks.ops.eblu.me` to the tailnet ingress
- [[sifaka|Sifaka]] - Music storage
- [[navidrome]] - Music streaming sibling on the same share
- [[rip-a-disc]] - How rips land in the library
- [[service-versions]] - Tracked upstream version inventory
