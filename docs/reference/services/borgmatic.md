---
title: Borgmatic
modified: 2026-10-04
last-reviewed: 2026-10-04
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
| **Talos-data config** | `~/.config/borgmatic/talos-data.yaml` (run with main at 2:00 AM) |
| **Main schedule** | Daily at 2:00 AM |
| **Photos schedule** | Daily at 4:00 AM |
| **Main targets** | [[sifaka]] local + BorgBase offsite |
| **Photos target** | BorgBase offsite only |

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten (migrating into heph docs; see [hephaestus](https://github.com/eblume/hephaestus))
- `~/forgejo` - Git forge data (repos, LFS, `custom/conf`; live WAL `forgejo.db` is excluded here and snapshotted separately below). The old `/opt/homebrew/var/forgejo` brew path was a dead husk after the source-build migration and was deleted on 2026-09-05 (blumeops #798). The one unique thing it held, the abandoned `eblume/hermes` scaffold, was deliberately discarded with it.
- `~/.config/borgmatic` - Borgmatic config
- `~/Documents` - Personal documents
- `~/.local/share/borgmatic/k8s-dumps/` - SQLite dumps from k8s pods
- `/Volumes/shower` - Archived shower service: prize photos + final DB snapshot (sifaka SMB mount)

**PostgreSQL databases:**
- `miniflux`, `teslamate`, `authentik`, `paperless` on [[postgresql]] (blumeops-pg)
- `immich` on immich-pg

**Local SQLite databases** (before-backup `sqlite3 .backup` online snapshot — WAL-safe, fails loud):
- [[hephaestus|heph]] hub - `~/.local/share/heph/heph.db` (canonical task/context store)
- [[forgejo]] - `~/forgejo/data/forgejo.db` (the live WAL-mode DB excluded from the `~/forgejo` source dir above; the git repos come from the directory)

**K8s SQLite databases (pre-backup dump via kubectl exec):**
- [[mealie]] - Recipe manager (`/app/data/mealie.db`)
- [[horkos]] - approval-queue dispatch (`/data/horkos.db`, on ringtail)

**K8s service-produced backup files (newest ferried off the PVC):**
- [[navidrome]] - music DB: users, play counts, playlists (navidrome's own `ND_BACKUP_*` snapshot in `/data/backup`)
- pulumi-stack-backup — Pulumi Cloud stack state, one ferry each for the two stacks `tail8d86e` and `eblu-me` (`pulumi stack export --show-secrets`, read straight off the PV via `pv:` mode; exports contain plaintext secret values — borg repo encryption is the control; restore: [[restore-pulumi-state]])

**K8s pod data directories (in-pod tar, streamed back):**
- paperless-ngx — document library: originals, archived, thumbnails (NFS media PVC on [[sifaka]]); multi-container pod, tarred in the `web` container

The SQLite snapshots and ferried backup files above are staged into
`~/.local/share/borgmatic/k8s-dumps/` (itself a source directory) by a
`commands:` hook with `before: configuration`, so they run **once per backup
run** rather than once per repository. A non-zero exit from any hook aborts the
whole run — a failed snapshot is never silently skipped.

**Immich photo library** (separate config, BorgBase offsite only):
- `/Volumes/photos/library` and `/Volumes/photos/upload` (sifaka SMB mount, ~128 GB); excludes `encoded-video/`, `thumbs/`, `backups/` — regenerable from originals

**Talos session state** (separate config, never pruned):
- `/home/talos/data` — every agent session ever (transcripts, service state, `session-index.sqlite`), in-pod tar → `~/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar`, `talos-data-*` archives in the same two repos. The config has no `keep_*` keys by design, and the main config's `match_archives: 'indri-*'` keeps any future prune off the prefix (heph 01M0GA6JPGQF96AM5JZKA37YSV). Single-session restore: [[backups]] → "Restoring a Single Session".

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

Not enforced: no prune has ever run and both main repos are append-only, so every archive produced so far is still present (264 in sifaka-local, 226 in borgbase-offsite as of 2026-10-04). The configured policy above is the policy a future prune would apply to `indri-*` archives only; talos-data is structurally exempt. See #1409.

## Verification

A LaunchAgent `mcquack.eblume.borgmatic-verify-photos` on [[indri]] verifies the
`borgbase-immich-photos` repo every Tuesday at 06:00, plus the 2nd of each
month (also 06:00). Each run performs:

- **Repo + archive-metadata check** — `borgmatic check --repository ... --only repository --only archives --force` — on every run. A stale `check` marker means the last run's check failed or the job itself did not run.
- **Full-data check** — `borgmatic check --only archives --only data --force` (borg `--verify-data`, valid only alongside the archive check) — only when the previous data-check marker is missing or older than 40 days.
- **Sampled test-restore** — when `/Volumes/photos` (the [[sifaka]] SMB mount) is mounted: 5 random regular files >1 MB from the newest archive are extracted via `borg extract --stdout` and sha256-compared against the live files under `/Volumes/photos` (a mismatch fails the run; benign when the live file changed after the last 04:00 backup). Files deleted from sifaka since the backup are skipped; the marker is written only when at least one file was compared.

Every result lands in the Loki-tailed logs
(`mcquack.borgmatic-verify-photos.{out,err}.log`). Success markers are written
to `/opt/homebrew/var/state/borgmatic-verification/` (`check`, `check-data`,
`test-restore`) and exposed by the hourly collector as
`borgmatic_last_verified_timestamp{repo="borgbase-immich-photos"}`,
`borgmatic_last_verified_data_timestamp{repo="borgbase-immich-photos"}`, and
`borgmatic_last_test_restore_timestamp{repo="borgbase-immich-photos"}`. The
`BorgmaticVerifyStale` Grafana alert fires when no check succeeds for 10 days.

**Verification proves the archives can be read and restored — it does NOT prove immutability.** The photos repo's BorgBase key is (pending dashboard confirmation) append-only on the server side, which protects the offsite copy from a compromised indri; but the sifaka-local mount `/Volumes/backups/borg` is an SMB share, not a `borg serve` endpoint, so its client-side `append_only` flag protects nothing against indri itself.

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
- `borgmatic_talos_data_last_success_timestamp` - Newest never-pruned talos-data archive, per repo (per-source signal the talos session reaper checks)
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage

The per-source size breakdown (`borgmatic_source_size_bytes`) is collected for
**local repos only** — it pulls the latest archive's full file manifest, cheap
locally but a heavy hourly transfer for a remote (ssh://) repo, so it is skipped
there. Remote repos still get the lightweight metrics above every hour.

Dashboard: "Borg Backups" in [[grafana]]

**Alert:** two Grafana rules (ntfy-infra): `BorgmaticStale` fires when any repo's newest main archive is older than 30h (for 1h) — missing series = OK; `BorgmaticStaleTalosData` fires when the newest reported talos-data archive is older than 30h, or when no repo reports the gauge at all (before the first archive lands). `BorgmaticStale` fires roughly 7h after a missed nightly run, well before BorgBase's own 2-missed-runs email. The main offsite repo was previously unmonitored (only sifaka + photos were scraped), so a failed offsite run produced no metric and no alert; it is now collected explicitly.

## Related

- [[backups|Backups]] - Full backup policy
- [[sifaka|Sifaka]] - Backup target
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
