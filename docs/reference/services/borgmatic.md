---
title: borgmatic
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
| **Repository** | `/Volumes/backups/borg/` on [[sifaka | Sifaka]] |

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten
- `/opt/homebrew/var/forgejo` - Git forge data
- `~/.config/borgmatic` - Borgmatic config
- `~/Documents` - Personal documents
- `~/Pictures` - Photos (see note below)

**iCloud Photos note:** macOS Photos.app defaults to "Optimize Mac Storage" which keeps only thumbnails locally. Borgmatic only backs up what's on disk, so iCloud-only photos are NOT backed up via this method.

**Databases:**
- `miniflux` on [[postgresql]]
- `teslamate` on [[postgresql]]

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

Metrics exposed via textfile collector to [[prometheus]]:
- `borgmatic_up` - Repository accessibility
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

Dashboard: "Borgmatic Backups" in [[grafana]]

## Related

- [[backups | Backups]] - Full backup policy
- [[sifaka | Sifaka]] - Backup target
- [[postgresql]] - Database backups
