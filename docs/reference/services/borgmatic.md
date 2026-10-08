---
title: Borgmatic
modified: 2026-10-06
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
| **Operational config** | `~/.config/borgmatic/operational.yaml` |
| **Photos config** | `~/.config/borgmatic/photos.yaml` |
| **Talos-data config** | `~/.config/borgmatic/talos-data.yaml` (run with main at 2:00 AM) |
| **Main schedule** | Daily at 2:00 AM |
| **Operational schedule** | Daily at 3:00 AM |
| **Photos schedule** | Daily at 4:00 AM |
| **Main targets** | [[sifaka]] local + BorgBase offsite |
| **Operational target** | sifaka local only (`/Volumes/backups/borg-operational/`, sibling of the archive-tier root) |
| **Photos target** | BorgBase offsite only |

## Tiers

The main and operational configs are independent agents (own configs, own
archive-name prefixes, own repos), so the archive tier is never mixed into the
rotating tier's archives and a prune in either config cannot reach the
other's archives.

**Archive tier (never pruned) — main config (`config.yaml`, 02:00):**
`~/code/personal/zk` and `~/Documents` only. No retention keys, no prune
action. Repos: `sifaka-borg-backups` ([[sifaka]] local) + `borgbase-offsite`
(BorgBase). No DB dumps run here — nightly data never lands in the
never-pruned `indri-*` archives, and the main config no longer writes DB dumps
to BorgBase offsite (that was the biggest driver of offsite churn; the tier
split stops it).

**Operational tier (rotating) — operational config (`operational.yaml`, 03:00):**
forgejo (minus pull mirrors and the live WAL DB), `~/.config/borgmatic`,
`k8s-dumps-op` (its own snapshot staging), `/Volumes/shower`, plus **all** the
pre-backup dumps the main config used to run — now staged into
`k8s-dumps-op/` instead of `k8s-dumps/`. Own local repo
`/Volumes/backups/borg-operational/` (label `sifaka-operational`, sibling of
the archive-tier root — borg 1.x refuses to create a repo inside an existing
one; the role creates it with `repo-create`, idempotent, and flips it off
append-only once — on borg 1.4 that flag makes `compact` a silent no-op, so
the rotation would cap archive counts while the repo grows unbounded on
disk), own `operational-*` prefix, `compression: auto,zstd`, retention
7 daily / 4 weekly / 12 monthly / yearly -1 (unlimited), enforced by the
ops agent's daily `create prune compact` run matched to `operational-*`
only; compact reclaims space on the local repo. The operational tier is local-only:
there is no offsite copy of the heph hub store, forgejo, or any database
newer than the cutover — losing indri and sifaka together loses them; the
offsite tier-B repo is a tracked follow-up on eblume/blumeops#1417 (needs a
BorgBase dashboard-created key).
The sifaka copy's immutability is client-side only — `/Volumes/backups` is an
SMB mount, not a `borg serve` endpoint, so local `append_only` protects
nothing against indri itself.

The backups share's SMB recycle bin must also stay disabled: a re-enabled
bin would capture every file the rotation's `compact` deletes, so nothing
would ever be reclaimed (8.7 GB had accumulated before the 2026-10-06
discovery; `borgmatic_recycle_size_bytes` goes non-zero once a re-enabled
bin has captured deletions — it reads 0 while present but empty).

## What Gets Backed Up

**Archive tier — main config (`config.yaml`, 02:00), never pruned:**
- `~/code/personal/zk` - Zettelkasten (migrating into heph docs; see [hephaestus](https://github.com/eblume/hephaestus))
- `~/Documents` - Personal documents (includes the [[1password]] encrypted export)

No dump hooks, no `keep_*` keys, no prune action. The main config no longer
writes DB dumps to the BorgBase offsite repo — nightly data must not live in
the never-pruned archives.

**Operational tier — operational config (`operational.yaml`, 03:00), rotating:**
- `~/forgejo` - Git forge data (repos, LFS, `custom/conf`), minus the live WAL `forgejo.db` (snapshotted via the before-backup hook) and the pull mirrors under `data/forgejo-repositories/mirrors` — 29 pull mirrors, 7.68 GB per Forgejo API 2026-10-04, ~93% of the ~7.9 GiB forgejo source; they re-fetch from upstream, so keeping them out of every archive saves that churn
- `~/.config/borgmatic` - the borgmatic configs (this operational.yaml is itself a source)
- `~/.local/share/borgmatic/k8s-dumps-op/` - the operational tier's snapshot staging (all pre-backup dumps land here)
- `/Volumes/shower` - archived shower service: prize photos + final DB snapshot (sifaka SMB mount)

**Databases and pod dumps** (snapshotted before every operational `create` run
only — the main config carries no dump hooks, so nightly data never lands in
the never-pruned `indri-*` archives):

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
- talos — session transcripts + service state (`/home/talos/data`), owned by its own config (`talos-data.yaml`) and excluded from the operational tier's tar loop

The SQLite snapshots and ferried backup files above are staged by a
`commands:` hook with `before: configuration`, so they run **once per backup
run** rather than once per repository. A non-zero exit from any hook aborts the
whole run — a failed snapshot is never silently skipped. Everything stages into
`~/.local/share/borgmatic/k8s-dumps-op/` (a source of the operational config);
the archive-tier config no longer targets any dump dir.

**Immich photo library** (separate config, BorgBase offsite only):
- `/Volumes/photos/library` and `/Volumes/photos/upload` (sifaka SMB mount, ~128 GB); excludes `encoded-video/`, `thumbs/`, `backups/` — regenerable from originals

**Talos session state** (separate config, never pruned — confirmed tier, eblume/blumeops#1417):
- `/home/talos/data` — every agent session ever (transcripts, service state, `session-index.sqlite`), in-pod tar → `~/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar`, `talos-data-*` archives in the same two repos. The config has no `keep_*` keys by design, and the main config's `match_archives: 'indri-*'` keeps any future prune off the prefix (heph 01M0GA6JPGQF96AM5JZKA37YSV). Measured cost (eblume/blumeops#1409, 2026-10-05): 79.6 MB/night deduplicated, ~2.4 GB/month per repo (~25% of nightly growth) — decision: stays never-pruned, with `compression: auto,zstd` on the config (new chunks only). Single-session restore: [[backups]] → "Restoring a Single Session".

**Not backed up (by design):**
- Forgejo pull mirrors (`~/forgejo/data/forgejo-repositories/mirrors`) — re-fetchable from upstream. After a forgejo restore, re-sync or recreate the mirrors — their DB rows survive in the forgejo.db snapshot but their git dirs are in no archive.
- ZIM archives (re-downloadable)
- Prometheus metrics (ephemeral)
- Loki logs (ephemeral)

## Retention Policy

| Config | Daily | Weekly | Monthly | Yearly |
|--------|-------|--------|---------|--------|
| Archive (main, 02:00) | — | — | — | — |
| Talos-data (02:00, same agent) | — | — | — | — |
| Operational (03:00) | 7 | 4 | 12 | -1 (unlimited) |
| Photos (04:00) | 7 | — | 12 | 1000 |

The main config is the **never-pruned archive tier**: it carries no `keep_*`
keys and no prune action, so its `indri-*` archives are kept forever. The
operational config's retention (7 daily / 4 weekly / 12 monthly / yearly -1,
unlimited) is enforced by the ops agent's `create prune compact` run, matched
to `operational-*` archives only. `/Volumes/shower` lives in the operational
tier; with `keep_yearly: -1`, each year's final archive is kept
forever, so the shower archive record (prize photos + final DB snapshot) still
survives in the yearlies.

Not enforced on the archive tier: no prune has ever run on those repos
and both are append-only, so every archive produced so far is still present (264 in sifaka-local, 226 in borgbase-offsite as of 2026-10-04). The configured policy above is the policy a future prune would apply to `indri-*` archives only; talos-data is structurally exempt. See #1409.

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

The main and operational configs set `retries: 3` / `retry_wait: 300`, so a transient failure on
a single repository (typically a broken SSH pipe partway through a large offsite
upload to BorgBase) is retried with linear backoff rather than failing the whole
run. borg checkpoints an interrupted `create`, so each retry resumes from where
it dropped. Only the failing repository is retried — the `before: configuration`
dump hooks run once and are not repeated. sifaka (local) and BorgBase (offsite)
are independent, so an offsite hiccup never affects the local archive.

## Monitoring

A one-shot script (launchd `StartInterval`, hourly) reads each repo's metadata
via `borg info`/`borg list` and writes textfile metrics to [[prometheus]], per
repository (`sifaka-local`, `borgbase-offsite`, `sifaka-operational`,
`borgbase-immich-photos`):
- `borgmatic_up` - Repository accessibility
- `borgmatic_last_archive_timestamp` - Last backup time
- `borgmatic_talos_data_last_success_timestamp` - Newest never-pruned talos-data archive, per repo (per-source signal the talos session reaper checks)
- `borgmatic_repo_deduplicated_size_bytes` - Disk usage
- `borgmatic_recycle_size_bytes` - sifaka backups share recycle-bin size in bytes (0 = bin absent; the bin must stay disabled)

The per-source size breakdown (`borgmatic_source_size_bytes`) is collected for
**local repos only** — it pulls the latest archive's full file manifest, cheap
locally but a heavy hourly transfer for a remote (ssh://) repo, so it is skipped
there. Remote repos still get the lightweight metrics above every hour.

Dashboard: "Borg Backups" in [[grafana]]

The operational repo's metrics are scoped to the `operational-*` prefix. The
main config no longer targets that repo, so a fresh `operational-*` archive
there means the operational run itself succeeded.

**Alert:** three Grafana rules (ntfy-infra): `BorgmaticStale` fires when any
repo's newest main archive is older than 30h (for 1h) — missing series = OK;
the operational repo is excluded from this rule (`BorgmaticOpsStale` is its
sole alert, so a missed 03:00 run fires one rule, not two);
`BorgmaticStaleTalosData` fires when the newest reported talos-data archive is
older than 30h, or when no repo reports the gauge at all (before the first
archive lands). `BorgmaticStale` fires roughly 7h after a missed nightly run,
well before BorgBase's own 2-missed-runs email. The main offsite repo was
previously unmonitored (only sifaka + photos were scraped), so a failed
offsite run produced no metric and no alert; it is now collected explicitly.
`BorgmaticOpsStale` fires when `sifaka-operational` has no archive at all, or
no new one in over 30h — NoData alerting, so the tier's first deploy (repo not
yet created) and any later repo loss can't fail silently.

## Related

- [[backups|Backups]] - Full backup policy
- [[sifaka|Sifaka]] - Backup target
- [[postgresql]] - Database backups
- [[restore-1password-backup]] - Recover 1Password from backup
