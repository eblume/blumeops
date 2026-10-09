---
title: Backups
modified: 2026-10-08
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
| Archive (never pruned) — talos-data | `~/.config/borgmatic/talos-data.yaml` (own config, same 02:00 agent, main first) | 02:00 | talos pod `/home/talos/data` (in-pod tar) | `sifaka-borg-backups`, `borgbase-offsite` | none — never pruned; tier confirmed 2026-10-05 (eblume/blumeops#1417) |
| Operational (rotating) | `~/.config/borgmatic/operational.yaml` | 03:00 | `~/forgejo` (minus mirrors + live WAL DB), `~/.config/borgmatic`, `k8s-dumps-op/`, `/Volumes/shower`, + all pre-backup dumps | `sifaka-operational` (`/Volumes/backups/borg-operational/`) — local-only for now | 7 daily / 4 weekly / 12 monthly / yearly -1 (unlimited) — enforced by the ops agent's daily `create prune compact` (eblume/blumeops#1417) |

The operational tier is **local-only** — there is no offsite copy of any of it.
From the night this provisions, the heph hub store (documented as the only
copy of all task/context data), forgejo, and every database above have no
offsite copy newer than the cutover: losing indri and sifaka together (fire,
theft, or ransomware over the SMB mount) loses them. An offsite tier-B repo is
a tracked follow-up on eblume/blumeops#1417 (needs a BorgBase
dashboard-created key). The main config no longer writes DB dumps to the
BorgBase offsite repo — that was the biggest driver of offsite churn, and
stopping it is part of the point of the split.

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
- Nothing prunes the archive repos today — the main and talos-data configs have no `prune` action and both repos are `append_only` — but a future change can't reach talos-data without a deliberate, separate PR (see #1409).

Measured cost (eblume/blumeops#1409, 2026-10-05): 79.6 MB/night deduplicated, ~2.4 GB/month per repo, ~25% of nightly growth — decision: talos-data stays never-pruned. The tier split adds `compression: auto,zstd` to this config (new chunks only), which slows that growth going forward.

Tonight's tar is staged into `~/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar` (deliberately *not* the main config's `k8s-dumps/` source directory) by a hook in the talos-data config; a failed dump aborts the run, so no archive without a fresh tar.

### Restoring a Single Session

```bash
ssh indri
export BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml"

# Newest talos-data archive in the local repo:
/opt/homebrew/bin/borg list /Volumes/backups/borg | grep talos-data-

# Stream the tar straight into tar(1) and pull out only the session (one pass,
# no 3 GB temp file; bsdtar matches the glob against member paths):
mkdir -p /tmp/restore
/opt/homebrew/bin/borg extract --stdout /Volumes/backups/borg::<talos-data-archive> \
  Users/erichblume/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar \
  | /usr/bin/tar -xvf - -C /tmp/restore "*<session-id>*"
# -> x data/sessions/<timestamp>_<session-id>.jsonl
```

Then `scp` the `.jsonl` to ringtail and copy it into the live session pod's `~/data/sessions/` under its original filename (`kubectl -n talos cp -c talos <file> talos/<talos-pod>:/home/talos/data/sessions/<file>`); compare `shasum -a 256` on indri with `sha256sum` in the pod. The tar is uncompressed; `session-index.sqlite` is in the same tar if the index needs it. (Offsite equivalent: `ssh -i ~/.ssh/borgbase_ed25519 u3ugi1x1@u3ugi1x1.repo.borgbase.com/./repo`.)

Restore talos sessions from a `talos-data-*` archive only — older `indri-*` main archives carry a stale `k8s-dumps/talos-data.tar` (removed from the live staging dir by the next provision; it disappears from new main archives at the next run).

### Restoring a Reaped (Tombstoned) Session

The session reaper (eblume/talos#295) deletes transcripts idle for `TALOS_SESSION_REAPER_DAYS` (default 30) days to keep the PVC small. Deletion is interlocked on the never-pruned `talos-data-*` archives above — a file is deleted only once both repos' last backup strictly post-dates it — so a reaped transcript is always recoverable. A reaped session keeps a tombstone in `~/data/tombstones.json` (id, name, origin, timestamps, cost) and renders as "archived, restore from borg" in the Issues view and session list.

Restoring one is the single-session restore above, with the catch that the reaper's idle clock is the transcript's *content* last-activity (rescanned into `session-index.sqlite` on every sync, not the file's mtime) — a restored file carries its old last-activity, so it is still idle. `kubectl cp` does **not** keep the original mtime, though: the copied file is stamped with the copy time, so the per-file backup interlock skips it (and counts it in `talos_reaper_blocked_total`) until the next nightly `talos-data-*` archive post-dates it. After that it is an ordinary idle candidate again.

- **Open the session after copying it back.** A live session (in the pod's in-memory session map, `isLive`) is exempt from the sweep — but only until the next talos pod restart. Restarts are frequent (every talos pin merge, often several a day), and the reaper sweeps once at boot, so an opened-but-untouched restored session is reaped again on the first sweep after the next restart, possibly the same day.
- **To keep it for another `TALOS_SESSION_REAPER_DAYS` days, post a turn in it.** That bumps the content last-activity and starts a fresh idle period.
- **Otherwise, expect it to be reaped again.** Harmless — the never-pruned `talos-data-*` archives still have it, and the tombstone is retained, so a re-restore is the same runbook again.

The restored row reappears in `GET /api/sessions` (and the transcript endpoint stops returning 410) as soon as the file is present and the index rescans it; its tombstone stays in `tombstones.json` as the historical record.

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
the last successful check is alerted via `BorgmaticVerifyStale` (10 days) and
the age of the last successful test restore via `BorgmaticTestRestoreStale`
(14 days).

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

## Restore notes

Forgejo restores from an `operational-*` archive bring back the DB snapshot —
including the rows for the 29 pull mirrors — but the mirrors' git dirs are
excluded from every archive, so re-sync or recreate the mirrors (clone from
upstream) after restoring. Operational DB dumps and forgejo state live in the
newest `operational-*` archive under `k8s-dumps-op/`; `indri-*` archives
predate the split and carry the old `k8s-dumps/` layout.

## Retention Policy

| Tier | Daily | Weekly | Monthly | Yearly |
|------|-------|--------|---------|--------|
| Archive (main, 02:00) | — | — | — | — |
| Talos-data (02:00, same agent) | — | — | — | — |
| Operational (03:00) | 7 | 4 | 12 | -1 (unlimited) |
| Immich photos (04:00) | 7 | — | 12 | 1000 |

The main config is the never-pruned archive tier (no `keep_*` keys, no prune
action). Operational retention (7 daily / 4 weekly / 12 monthly / yearly -1,
unlimited) is enforced by the ops agent's daily `create prune compact` run,
matched to `operational-*` archives only. `keep_yearly: -1` keeps each year's
final operational archive forever, so the `/Volumes/shower` archive record
(photos + final DB snapshot) survives in the yearlies even though it moved to
the rotating tier.

Pruning is enabled on the operational repo only — the main and talos-data
repos stay append-only with no prune action — so the retention table above is
enforced behavior on the operational tier and configured policy on the
never-pruned tiers. Talos-data is prune-exempt by design, alongside the
archive tier (above).

## Backup Targets

| Repository | Location | Label | Backs up |
|------------|----------|-------|----------|
| `/Volumes/backups/borg/` | [[sifaka]] (local NAS) | `sifaka-borg-backups` | indri data |
| `ssh://u3ugi1x1@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-offsite` | indri data |
| `/Volumes/backups/borg-operational/` | [[sifaka]] (local NAS) | `sifaka-operational` | operational tier (`operational-*`) only — the main config no longer targets this repo |
| `ssh://xcrtl5tg@...repo.borgbase.com/./repo` | BorgBase (offsite) | `borgbase-immich-photos` | immich photos |

The `backups` share's SMB recycle bin must stay **disabled** (verified
`enable recycle bin=no` in DSM on 2026-10-06): it captures the files a
`compact` or `prune` deletes, so rotation would reclaim nothing — 8.7 GB of
superseded borg index/lock files had accumulated before the discovery.

## Monitoring

Metrics exposed to [[prometheus]]:
- `borgmatic_up` - Repository accessible
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_talos_data_last_success_timestamp` - Newest never-pruned talos-data archive per repo
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage
- `borgmatic_recycle_size_bytes` - sifaka backups share recycle-bin size (0 = bin absent, the required state)

Three alerts: `BorgmaticStale` when a repo's newest main archive is over
30h old (`sifaka-operational` excluded — `BorgmaticOpsStale` is its sole
alert, so a missed 03:00 run fires one rule, not two),
`BorgmaticStaleTalosData` when the newest reported talos-data archive is
over 30h old or no repo reports the gauge at all (before the first archive
lands), and `BorgmaticOpsStale` (NoData alerting) when `sifaka-operational`
has no archive at all, or no new one in over 30h.

Dashboard: "Borg Backups" in [[grafana]]

## Related

- [[borgmatic]] - Backup system details
- [[sifaka|Sifaka]] - Backup storage
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
