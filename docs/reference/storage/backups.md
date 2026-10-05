---
title: Backups
modified: 2026-10-04
last-reviewed: 2026-10-04
tags:
  - storage
  - backup
---

# Backup Policy

Daily automated backups from [[indri]] to [[sifaka|Sifaka]] NAS.

## Schedule

| Time | Frequency | System |
|------|-----------|--------|
| 2:00 AM | Daily | [[borgmatic]] main config (archive tier) |
| 3:00 AM | Daily | [[borgmatic]] operational config (operational tier) |

## Tiers

| Tier | Config | Schedule | Sources | Repos | Retention |
|------|---------|----------|---------|-------|-----------|
| Archive (never pruned) | `~/.config/borgmatic/config.yaml` | 02:00 | `~/code/personal/zk`, `~/Documents` | `sifaka-borg-backups` (`/Volumes/backups/borg/`), `borgbase-offsite` | none — never pruned (no `keep_*` keys, no prune action) |
| Operational (rotating) | `~/.config/borgmatic/operational.yaml` | 03:00 | `~/forgejo` (minus mirrors + live WAL DB), `~/.config/borgmatic`, `k8s-dumps-op/`, `/Volumes/shower`, + all pre-backup dumps | `sifaka-operational` (`/Volumes/backups/borg/operational/`) — local-only for now | 7 daily / 4 weekly / 12 monthly / yearly -1 — declared but inert until prune lands (eblume/blumeops#1417) |

The operational tier is local-only for now: an offsite tier-B copy is deferred
(needs a BorgBase dashboard-created key). The main config no longer writes DB
dumps to the BorgBase offsite repo — that was the biggest driver of offsite
churn, and stopping it is part of the point of the split.

## What Gets Backed Up

### Directories

**Archive tier (main config, 02:00)** — the only sources are:

| Path | Description | Priority |
|------|-------------|----------|
| `~/code/personal/zk` | Zettelkasten notes (migrating into heph docs) | Critical |
| `~/Documents` | Personal documents (includes [[1password]] encrypted export) | High |

**Operational tier (operational config, 03:00)** — everything rotating:

| Path | Description |
|------|-------------|
| `~/forgejo` | Git forge data, minus the pull mirrors and the live WAL DB (both excluded per [[borgmatic]]) |
| `~/.config/borgmatic` | The borgmatic configs themselves |
| `~/.local/share/borgmatic/k8s-dumps-op` | Staging for the pre-backup dumps (see Databases table) |
| `/Volumes/shower` | Archived shower service: prize photos + final DB snapshot (sifaka SMB mount) |

All the pre-backup dumps (local sqlite, k8s, postgres) run in the operational
tier only, staged into `k8s-dumps-op/`. `keep_yearly: -1` means each year's
final operational archive is kept forever, so the shower archive record (photos
+ final DB snapshot) still survives in the yearlies.

### Databases

| Database | Cluster | Host | Method |
|----------|---------|------|--------|
| miniflux | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| teslamate | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| authentik | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| paperless | blumeops-pg | [[postgresql|pg.ops.eblu.me:5434]] | pg_dump stream |
| immich | immich-pg | [[postgresql|pg.ops.eblu.me:5433]] | pg_dump stream |
| forgejo | — (SQLite) | indri local | before-backup `sqlite3 .backup` (WAL-safe online snapshot) |
| heph | — (SQLite) | indri local | before-backup `sqlite3 .backup` (WAL-safe online snapshot) |
| mealie | — (SQLite) | k8s pod (ringtail) | in-pod python3 sqlite3 .backup |
| horkos | — (SQLite) | k8s pod (ringtail) | in-pod python3 sqlite3 .backup |
| navidrome | — (SQLite) | k8s pod (ringtail) | navidrome `ND_BACKUP_*` snapshot, newest ferried off PVC |
| audiobookshelf | — (SQLite) | k8s pod (ringtail) | ABS built-in scheduled backup zips config+metadata, newest ferried off PVC |

All dumps below run in the operational config (03:00) only, staged via a
`commands:` before-hook into `~/.local/share/borgmatic/k8s-dumps-op/` (a source
of that config). The main archive-tier config carries no dump hooks, so nightly
data never lands in the never-pruned `indri-*` archives — and no DB dumps are
written to the BorgBase offsite repo anymore, which stops the offsite churn.

## K8s Pod Data Directories

| Pod | Data | Method |
|-----|------|--------|
| talos | All session transcripts + service state (meta.json, crons.json, settings.json) | in-pod tar → own never-pruned config (see below) |
| paperless | Document library — originals, archived, thumbnails (NFS media PVC on [[sifaka]]) | in-pod tar, streamed back |

## Talos Session State (Never Pruned)

Talos agent sessions (`/home/talos/data` — session transcripts, service state, `session-index.sqlite`) are backed up by a **separate borgmatic config** (`~/.config/borgmatic/talos-data.yaml`, run in the same 2:00 AM agent, main first) with its own `talos-data-*` archive prefix in the same two repos. Design intent: **every session is stored forever** (heph 01M0GA6JPGQF96AM5JZKA37YSV) — and this holds structurally, not by accident:

- The talos-data config has **no `keep_*` keys**, so it never prunes.
- The main config pins `archive_name_format: 'indri-{now…}'` + `match_archives: 'indri-*'`, so a prune enabled there (or anywhere else) can only ever reach `indri-*` archives.
- Nothing prunes today at all — no `prune` run exists anywhere and both repos are `append_only` — but a future change can't reach talos-data without a deliberate, separate PR (see #1409).

Tonight's tar is staged into `~/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar` (deliberately *not* the main config's `k8s-dumps/` source directory) by a hook in the talos-data config; a failed dump aborts the run, so no archive without a fresh tar.

### Restoring a Single Session

```bash
ssh indri
export BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml"

# Newest talos-data archive in the local repo:
/opt/homebrew/bin/borg list /Volumes/backups/borg | grep talos-data-

# Stream the tar out (don't leave a 3 GB file on disk) and find the session:
/opt/homebrew/bin/borg extract --stdout /Volumes/backups/borg::<talos-data-archive> \
  Users/erichblume/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar > /tmp/talos-data.tar
tar -tf /tmp/talos-data.tar | grep <session-id>

# Extract just that session file:
mkdir -p /tmp/restore
tar -xf /tmp/talos-data.tar -C /tmp/restore <the-member-path-from-above>
```

Then copy the `.jsonl` into the live session pod's `~/data/sessions/` from ringtail (`sudo k3s kubectl cp ... talos-<pod>:/home/talos/data/sessions/`). The tar is uncompressed; `session-index.sqlite` is in the same tar if the index needs it. (Offsite equivalent: `ssh -i ~/.ssh/borgbase_ed25519 u3ugi1x1@u3ugi1x1.repo.borgbase.com/./repo`.)

Restore talos sessions from a `talos-data-*` archive only — older `indri-*` main archives carry a stale `k8s-dumps/talos-data.tar` (removed from the live staging dir by the next provision; it disappears from new main archives at the next run).

## Immich Photo Library (Offsite Only)

The [[immich]] photo library lives on [[sifaka]] at `/volume1/photos` (SMB-mounted on [[indri]] as `/Volumes/photos`). Since sifaka is already the local backup target, photos are backed up to BorgBase offsite only — not back to sifaka.

| Property | Value |
|----------|-------|
| **Config** | `~/.config/borgmatic/photos.yaml` |
| **Schedule** | Daily at 4:00 AM (offset from main backup) |
| **Source** | `/Volumes/photos/library` + `/Volumes/photos/upload` (sifaka SMB mount) |
| **Target** | BorgBase `borgbase-immich-photos` repo |
| **Size** | ~128 GB |

Uses the same encryption passphrase and SSH key as the main borgmatic config.

The `borgbase-immich-photos` repo is verified on a schedule (weekly
`borgmatic check`, monthly full-data check, and a weekly sampled
test-restore against the live sifaka files — see [[borgmatic]]); the age of
the last successful check is alerted via `BorgmaticVerifyStale` (10 days).

## Sifaka-Native Data

Bulk media lives directly on [[sifaka]] (music files served by [[navidrome]], video via [[jellyfin]]). See [[sifaka]] for data protection details. Note this covers only the *media files* — [[navidrome]]'s own database (users, play counts, playlists) lives on a ringtail PVC and is backed up separately via the Databases table above. The paperless document library (/volume1/paperless) is additionally backed up offsite via the in-pod tar dump above, so it is not only RAID-5-protected.

## What Is NOT Backed Up

| Data | Reason |
|------|--------|
| ZIM archives (`~/transmission/`) | Re-downloadable via torrent |
| Prometheus metrics | Ephemeral, in k8s PVC |
| Loki logs | Ephemeral, in k8s PVC |
| devpi cache (`~/devpi/server-dir/` on indri) | Re-fetchable from PyPI on first request |
| Forgejo pull mirrors (`~/forgejo/data/forgejo-repositories/mirrors`, 29 repos, ~7.7 GB) | Re-fetchable from upstream |

## Retention Policy

| Tier | Daily | Weekly | Monthly | Yearly |
|------|-------|--------|---------|--------|
| Archive (main, 02:00) | — | — | — | — |
| Operational (03:00) | 7 | 4 | 12 | -1 (unlimited) |
| Immich photos (04:00) | 7 | — | 12 | 1000 |

The main config is the never-pruned archive tier (no `keep_*` keys, no prune
action). Operational retention is declared but inert until a separate PR
enables prune (eblume/blumeops#1417). `keep_yearly: -1` keeps each year's final
operational archive forever, so the `/Volumes/shower` archive record (photos +
final DB snapshot) survives in the yearlies even though it moved to the
rotating tier.

Pruning is not currently enabled on any repo (append-only, no prune run); the table is the configured policy, not enforced behavior. Talos-data is the one prune-exempt source by design (above).

## Backup Targets

| Repository | Location | Label | Backs up |
|------------|----------|-------|----------|
| `/Volumes/backups/borg/` | [[sifaka]] (local NAS) | `sifaka-borg-backups` | indri data |
| `ssh://u3ugi1x1@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-offsite` | indri data |
| `/Volumes/backups/borg/operational/` | [[sifaka]] (local NAS) | `sifaka-operational` | operational tier (`operational-*`) only — the main config no longer targets this repo |
| `ssh://xcrtl5tg@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-immich-photos` | immich photos |

## Monitoring

Metrics exposed to [[prometheus]]:
- `borgmatic_up` - Repository accessible
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_talos_data_last_success_timestamp` - Newest never-pruned talos-data archive per repo
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

Two alerts: `BorgmaticStale` when a repo's newest main archive is over 30h old, and `BorgmaticStaleTalosData` when the newest reported talos-data archive is over 30h old, or when no repo reports the gauge at all (before the first archive lands).

Dashboard: "Borg Backups" in [[grafana]]

## Related

- [[borgmatic]] - Backup system details
- [[sifaka|Sifaka]] - Backup storage
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
