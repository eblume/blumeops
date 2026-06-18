---
title: Backups
modified: 2026-03-27
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
| `~/code/personal/zk` | Zettelkasten notes (migrating into heph docs) | Critical |
| `/opt/homebrew/var/forgejo` | Git repositories | Critical |
| `~/.config/borgmatic` | Backup config | High |
| `~/Documents` | Personal documents (includes [[1password]] encrypted export) | High |

### Databases

| Database | Cluster | Host | Method |
|----------|---------|------|--------|
| miniflux | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| teslamate | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| authentik | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| paperless | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| immich | immich-pg | [[postgresql|pg.ops.eblu.me:5433]] | pg_dump stream |
| heph | — (SQLite) | indri local | before-backup `sqlite3 .backup` (WAL-safe online snapshot) |
| mealie | — (SQLite) | k8s pod | kubectl exec sqlite3 .backup |
| shower | — (SQLite) | k8s pod (ringtail) | kubectl exec sqlite3 .backup |
| navidrome | — (SQLite) | k8s pod (ringtail) | navidrome `ND_BACKUP_*` snapshot, newest ferried off PVC |

## Immich Photo Library (Offsite Only)

The [[immich]] photo library lives on [[sifaka]] at `/volume1/photos` (SMB-mounted on [[indri]] as `/Volumes/photos`). Since sifaka is already the local backup target, photos are backed up to BorgBase offsite only — not back to sifaka.

| Property | Value |
|----------|-------|
| **Config** | `~/.config/borgmatic/photos.yaml` |
| **Schedule** | Daily at 4:00 AM (offset from main backup) |
| **Source** | `/Volumes/photos` (sifaka SMB mount) |
| **Target** | BorgBase `borgbase-immich-photos` repo |
| **Size** | ~128 GB |

Uses the same encryption passphrase and SSH key as the main borgmatic config.

## Sifaka-Native Data

Bulk media lives directly on [[sifaka]] (music files served by [[navidrome]], video via [[jellyfin]]). See [[sifaka]] for data protection details. Note this covers only the *media files* — [[navidrome]]'s own database (users, play counts, playlists) lives on a ringtail PVC and is backed up separately via the Databases table above.

## What Is NOT Backed Up

| Data | Reason |
|------|--------|
| ZIM archives (`~/transmission/`) | Re-downloadable via torrent |
| Prometheus metrics | Ephemeral, in k8s PVC |
| Loki logs | Ephemeral, in k8s PVC |
| devpi cache (`~/devpi/server-dir/` on indri) | Re-fetchable from PyPI on first request |

## Retention Policy

| Period | Retention |
|--------|-----------|
| Daily | 7 backups |
| Monthly | 12 backups |
| Yearly | 1000 backups |

## Backup Targets

| Repository | Location | Label | Backs up |
|------------|----------|-------|----------|
| `/Volumes/backups/borg/` | [[sifaka]] (local NAS) | `sifaka-borg-backups` | indri data |
| `ssh://u3ugi1x1@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-offsite` | indri data |
| `ssh://xcrtl5tg@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-immich-photos` | immich photos |

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
- [[restore-1password-backup]] - Recover 1Password from backup
