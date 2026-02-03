---
title: Backup Policy
tags:
  - storage
  - backup
---

# Backup Policy

Daily automated backups from [[infrastructure/indri|Indri]] to [[storage/sifaka|Sifaka]] NAS.

## Schedule

| Time | Frequency | System |
|------|-----------|--------|
| 2:00 AM | Daily | [[services/borgmatic|Borgmatic]] |

## What Gets Backed Up

### Directories

| Path | Description | Priority |
|------|-------------|----------|
| `~/code/personal/zk` | Zettelkasten notes | Critical |
| `/opt/homebrew/var/forgejo` | Git repositories | Critical |
| `~/.config/borgmatic` | Backup config | High |
| `~/Documents` | Personal documents | High |
| `~/Pictures` | Photos | Medium |

### Databases

| Database | Host | Method |
|----------|------|--------|
| miniflux | [[services/postgresql|pg.ops.eblu.me]] | pg_dump stream |
| teslamate | [[services/postgresql|pg.ops.eblu.me]] | pg_dump stream |

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

Repository: `/Volumes/backups/borg/` on [[storage/sifaka|Sifaka]]

## Monitoring

Metrics exposed to [[services/prometheus|Prometheus]]:
- `borgmatic_up` - Repository accessible
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

Dashboard: "Borgmatic Backups" in [[services/grafana|Grafana]]

## Related

- [[services/borgmatic|Borgmatic]] - Backup system details
- [[storage/sifaka|Sifaka]] - Backup storage
- [[services/postgresql|PostgreSQL]] - Database backups
