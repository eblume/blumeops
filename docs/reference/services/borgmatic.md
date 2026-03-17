---
title: Borgmatic
modified: 2026-03-16
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
| **Repository** | `/Volumes/backups/borg/` on [[sifaka|Sifaka]] |

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten
- `/opt/homebrew/var/forgejo` - Git forge data
- `~/.config/borgmatic` - Borgmatic config
- `~/Documents` - Personal documents
- `~/.local/share/borgmatic/k8s-dumps/` - SQLite dumps from k8s pods

**PostgreSQL databases:**
- `miniflux` on [[postgresql]]
- `teslamate` on [[postgresql]]

**K8s SQLite databases (pre-backup dump via kubectl exec):**
- [[mealie]] - Recipe manager (`/app/data/mealie.db`)

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

- [[backups|Backups]] - Full backup policy
- [[sifaka|Sifaka]] - Backup target
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
