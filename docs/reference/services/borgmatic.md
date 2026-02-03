---
title: Borgmatic
tags:
  - service
  - backup
---

# Borgmatic

Daily backup system using Borg backup, running on indri.

## Quick Reference

| Property | Value |
|----------|-------|
| **Install** | mise (pipx) |
| **Config** | `~/.config/borgmatic/config.yaml` |
| **Schedule** | Daily at 2:00 AM |
| **Repository** | `/Volumes/backups/borg/` on [[Sifaka NAS|Sifaka]] |

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten
- `/opt/homebrew/var/forgejo` - Git forge data
- `~/.config/borgmatic` - Borgmatic config
- `~/Documents` - Personal documents
- `~/Pictures` - Photos

**Databases:**
- `miniflux` on [[PostgreSQL]]
- `teslamate` on [[PostgreSQL]]

**Not backed up (by design):**
- ZIM archives (re-downloadable)
- Prometheus metrics (ephemeral)
- Loki logs (ephemeral)

## Retention Policy

| Period | Count |
|--------|-------|
| Daily | 7 |
| Monthly | 12 |
| Yearly | 1000 |

## Monitoring

Metrics exposed via textfile collector to [[Prometheus]]:
- `borgmatic_up` - Repository accessibility
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

Dashboard: "Borgmatic Backups" in [[Grafana]]

## Related

- [[Backup Policy|Backups]] - Full backup policy
- [[Sifaka NAS|Sifaka]] - Backup target
- [[PostgreSQL]] - Database backups
