---
title: Borgmatic
modified: 2026-08-24
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
| **Main config** | `~/.config/borgmatic/config.yaml` |
| **Photos config** | `~/.config/borgmatic/photos.yaml` |
| **Main schedule** | Daily at 2:00 AM |
| **Photos schedule** | Daily at 4:00 AM |
| **Main targets** | [[sifaka]] local + BorgBase offsite |
| **Photos target** | BorgBase offsite only |

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten (migrating into heph docs; see [hephaestus](https://github.com/eblume/hephaestus))
- `~/forgejo` - Git forge data (repos, LFS, `custom/conf`; live WAL `forgejo.db` is excluded here and snapshotted separately below). The old `/opt/homebrew/var/forgejo` brew path is a dead husk since the source-build migration.
- `~/.config/borgmatic` - Borgmatic config
- `~/Documents` - Personal documents
- `~/.local/share/borgmatic/k8s-dumps/` - SQLite dumps from k8s pods

**PostgreSQL databases:**
- `miniflux`, `teslamate`, `authentik`, `paperless` on [[postgresql]] (blumeops-pg)
- `immich` on immich-pg

**Local SQLite databases** (before-backup `sqlite3 .backup` online snapshot — WAL-safe, fails loud):
- [[hephaestus|heph]] hub - `~/.local/share/heph/heph.db` (canonical task/context store)

**K8s SQLite databases (pre-backup dump via kubectl exec):**
- [[mealie]] - Recipe manager (`/app/data/mealie.db`)
- `shower` - prize app (`/app/data/db.sqlite3`, on ringtail)

**K8s service-produced backup files (newest ferried off the PVC):**
- [[navidrome]] - music DB: users, play counts, playlists (navidrome's own `ND_BACKUP_*` snapshot in `/data/backup`)

**K8s pod data directories (in-pod tar, streamed back):**
- talos — session transcripts + service state (`/home/talos/data`)
- paperless-ngx — document library: originals, archived, thumbnails (NFS media PVC on [[sifaka]]); multi-container pod, tarred in the `web` container

The SQLite snapshots and ferried backup files above are staged into
`~/.local/share/borgmatic/k8s-dumps/` (itself a source directory) by a
`commands:` hook with `before: configuration`, so they run **once per backup
run** rather than once per repository. A non-zero exit from any hook aborts the
whole run — a failed snapshot is never silently skipped.

**Immich photo library** (separate config, BorgBase offsite only):
- `/Volumes/photos` (sifaka SMB mount, ~128 GB)

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

## Resilience

The main config sets `retries: 3` / `retry_wait: 300`, so a transient failure on
a single repository (typically a broken SSH pipe partway through a large offsite
upload to BorgBase) is retried with linear backoff rather than failing the whole
run. borg checkpoints an interrupted `create`, so each retry resumes from where
it dropped. Only the failing repository is retried — the `before: configuration`
dump hooks run once and are not repeated. sifaka (local) and BorgBase (offsite)
are independent, so an offsite hiccup never affects the local archive.

## Monitoring

A one-shot script (launchd `StartInterval`, hourly) reads each repo's metadata
via `borg info`/`borg list` and writes textfile metrics to [[prometheus]], per
repository (`sifaka-local`, `borgbase-offsite`, `borgbase-immich-photos`):
- `borgmatic_up` - Repository accessibility
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

The per-source size breakdown (`borgmatic_source_size_bytes`) is collected for
**local repos only** — it pulls the latest archive's full file manifest, cheap
locally but a heavy hourly transfer for a remote (ssh://) repo, so it is skipped
there. Remote repos still get the lightweight metrics above every hour.

Dashboard: "Borgmatic Backups" in [[grafana]]

**Alert:** `BorgmaticStale` (Grafana, ntfy-infra) fires when any repo's newest
archive is older than 30h (for 1h) — roughly 7h after a missed nightly run,
well before BorgBase's own 2-missed-runs email. The main offsite repo was
previously unmonitored (only sifaka + photos were scraped), so a failed offsite
run produced no metric and no alert; it is now collected explicitly.

## Related

- [[backups|Backups]] - Full backup policy
- [[sifaka|Sifaka]] - Backup target
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
