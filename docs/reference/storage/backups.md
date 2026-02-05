---
title: backup-policy
tags:
  - storage
  - backup
---

# Backup Policy

Daily automated backups from [[indri]] to [[sifaka|Sifaka]] NAS.

## Schedule

| Time | Frequency | System |
|------|-----------|--------|
| 2:00 AM | Daily | [[borgmatic]] |

## What Gets Backed Up

### Directories

| Path | Description | Priority |
|------|-------------|----------|
| `~/code/personal/zk` | Zettelkasten notes | Critical |
| `/opt/homebrew/var/forgejo` | Git repositories | Critical |
| `~/.config/borgmatic` | Backup config | High |
| `~/Documents` | Personal documents | High |

### Databases

| Database | Host | Method |
|----------|------|--------|
| miniflux | [[postgresql|pg.ops.eblu.me]] | pg_dump stream |
| teslamate | [[postgresql|pg.ops.eblu.me]] | pg_dump stream |

## Sifaka-Native Data

Some data lives directly on [[sifaka]] rather than being backed up to it (photos via [[immich]], music via [[navidrome]], video via [[jellyfin]]). See [[sifaka]] for data protection details.

## What Is NOT Backed Up

| Data | Reason |
|------|--------|
| ZIM archives (`~/transmission/`) | Re-downloadable via torrent |
| Prometheus metrics | Ephemeral, in k8s PVC |
| Loki logs | Ephemeral, in k8s PVC |
| devpi cache | Re-fetchable from PyPI |

## Retention Policy

| Period | Retention |
|--------|-----------|
| Daily | 7 backups |
| Monthly | 12 backups |
| Yearly | 1000 backups |

## Backup Target

Repository: `/Volumes/backups/borg/` on [[sifaka|Sifaka]]

## Monitoring

Metrics exposed to [[prometheus]]:
- `borgmatic_up` - Repository accessible
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

Dashboard: "Borgmatic Backups" in [[grafana]]

## Related

- [[borgmatic]] - Backup system details
- [[sifaka|Sifaka]] - Backup storage
- [[postgresql]] - Database backups
