---
title: Borgmatic
modified: 2026-10-20
last-reviewed: 2026-10-13
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
`~/code/personal/zk`, `~/Documents`, `~/forgejo` (minus pull mirrors, the
live WAL DB, and the regenerable/ephemeral churn), the never-lose dumps staged into `k8s-dumps-archive/` (heph,
forgejo.db, horkos, paperless-media tar), and the paperless pg_dump via a
`postgresql_databases` block. No retention keys, no prune action,
`compression: auto,zstd` (new chunks only). Repos: `sifaka-borg-backups`
([[sifaka]] local) + `borgbase-offsite` (BorgBase, append-only). The never-lose
dumps land in the never-pruned `indri-*` archives and write to the BorgBase
offsite repo again — deliberate, since these are never-lose data; the bulk of
the old offsite churn is still stopped because the operational dumps stay out
of this repo.

**Operational tier (rotating) — operational config (`operational.yaml`, 03:00):**
`~/.config/borgmatic`, `k8s-dumps-op` (its own snapshot staging: mealie,
navidrome, audiobookshelf, pulumi), `/Volumes/shower`, plus the
authentik/miniflux/teslamate/immich pg dumps (no `exclude_patterns` left —
no excluded sources). Own local repo
`/Volumes/backups/borg-operational/` (label `sifaka-operational`, sibling of
the archive-tier root — borg 1.x refuses to create a repo inside an existing
one; the ops-admin oneshot creates it with `repo-create` (idempotent) and flips
it off append-only once — on borg 1.4 that flag makes `compact` a silent
no-op, so
the rotation would cap archive counts while the repo grows unbounded on
disk), own `operational-*` prefix, `compression: auto,zstd`, retention
7 daily / 4 weekly / 12 monthly / yearly -1 (unlimited), enforced by the
ops agent's daily `create prune compact` run matched to `operational-*`
only; compact reclaims space on the local repo. The operational tier is local-only:
there is no offsite copy of the operational dumps (mealie, navidrome,
audiobookshelf, pulumi, authentik/miniflux/teslamate/immich) or
`/Volumes/shower` newer than the cutover — losing indri and sifaka together
loses them; the offsite tier-B repo is a tracked follow-up on
eblume/blumeops#1417 (needs a BorgBase dashboard-created key). The never-lose
dumps (heph, forgejo, horkos, paperless-media, paperless pg) do not depend on
that follow-up — they run in the archive config and land offsite.
The sifaka copy's immutability is client-side only — `/Volumes/backups` is an
SMB mount, not a `borg serve` endpoint, so local `append_only` protects
nothing against indri itself.

The operational repo's lifecycle is managed by the oneshot LaunchAgent
`mcquack.eblume.borgmatic-ops-admin` running the role-deployed
`~/bin/borgmatic-ops-repo-admin`, which the provision kicks off once per
run and waits on — a non-zero exit fails the provision. The agent execs
the TCC-granted borgmatic pipx venv python (`borgmatic_venv_python`, the
same wrapper as the borgmatic-verify-photos agent), which spawns the
script: launchd's responsible process must hold the Network Volumes grant
to read the share's content — the borg repo lock — and neither sshd nor
/bin/sh holds it, so the same borg commands EPERM over ssh or under a
plain-script agent (eblume/blumeops#1773). It is an idempotent no-op on
a healthy repo (`repo-create` only when the repo's README is absent,
`append_only` flipped to 0 only when it reads 1). The provision's
ssh-side mount assert (that `/Volumes/backups` is the sifaka mount) still
gates the run, and the script re-guards the mount itself. Output lands in
`~/Library/Logs/mcquack.borgmatic-ops-admin.{out,err}.log`, tailed into
Grafana like the other agents' logs.

The backups share's SMB recycle bin must also stay disabled: a re-enabled
bin would capture every file the rotation's `compact` deletes, so nothing
would ever be reclaimed (8.7 GB had accumulated before the 2026-10-06
discovery; `borgmatic_recycle_size_bytes` goes non-zero once a re-enabled
bin has captured deletions — it reads 0 while present but empty).

## What Gets Backed Up

**Archive tier — main config (`config.yaml`, 02:00), never pruned:**
- `~/code/personal/zk` - Zettelkasten (migrating into heph docs; see [hephaestus](https://github.com/eblume/hephaestus))
- `~/Documents` - Personal documents (includes the [[1password]] encrypted export)
- `~/forgejo` - Git forge data (repos, LFS, `custom/conf`), minus the pull mirrors under `data/forgejo-repositories/mirrors` (29 pull mirrors, 7.68 GB per Forgejo API 2026-10-04 — re-fetchable from upstream), the live WAL `forgejo.db` (snapshotted into `k8s-dumps-archive/` instead), and the regenerable or ephemeral churn (`data/actions_log`, `data/indexers`, `data/queues`, `data/actions_artifacts`, `data/sessions`, `data/tmp`, `log/`) — the tier never prunes, so only never-lose data rides in (the git repos incl. LFS and `custom/conf`, the DB snapshot, `attachments`, `packages`, `ssh`, `jwt`); all excluded via `exclude_patterns`
- `~/.local/share/borgmatic/k8s-dumps-archive/` - the archive tier's snapshot staging (never-lose dumps: heph, forgejo.db, horkos, paperless-media tar)

The archive tier carries the dump hooks and the `postgresql_databases` block,
so never-lose nightly data lands in the never-pruned `indri-*` archives — and
on BorgBase offsite, deliberately: these are never-lose data. No `keep_*`
keys, no prune action.

**Operational tier — operational config (`operational.yaml`, 03:00), rotating:**
- `~/.config/borgmatic` - the borgmatic configs (this operational.yaml is itself a source)
- `~/.local/share/borgmatic/k8s-dumps-op/` - the operational tier's snapshot staging (mealie, navidrome, audiobookshelf, pulumi land here)
- `/Volumes/shower` - archived shower service: prize photos + final DB snapshot (sifaka SMB mount)

**Databases and pod dumps** (snapshotted before every `create` run — the
never-lose set runs in the archive config (02:00) and lands in the
never-pruned `indri-*` archives, the rest in the operational config (03:00)).

All ringtail k8s dumps run through ringtail's `borgmatic` dump endpoint (dedicated `borgmatic` user, forced command — [[ringtail]] §Borgmatic dump endpoint, eblume/blumeops#1484; per-principal SSH per [[per-principal-ssh]]); indri sends only the dump name.

**Archive tier (02:00) — never-lose (staged into `k8s-dumps-archive/`):**

**PostgreSQL:**
- `paperless` on [[postgresql]] (blumeops-pg) — pg_dump via the main config's `postgresql_databases` block

**Local SQLite databases** (before-backup hook runs `~/bin/borgmatic-sqlite-dump`: a `VACUUM INTO` one-read-transaction snapshot — consistent on a busy WAL source and hard-bounded by a 20-min timeout, so a stuck snapshot fails the run instead of starving it; a non-zero exit aborts the whole backup):
- [[hephaestus|heph]] hub - `~/.local/share/heph/heph.db` (canonical task/context store, only copy)
- [[forgejo]] - `~/forgejo/data/forgejo.db` (the live WAL-mode DB excluded from the `~/forgejo` source dir above; the git repos come from the directory)

**K8s dumps:**
- [[horkos]] - approval-queue dispatch (`/data/horkos.db`, on ringtail) — SQLite dump, only copy
- paperless-media — document library: originals, archived, thumbnails (NFS media PVC on [[sifaka]]); multi-container pod, tarred in the `web` container — in-pod tar, streamed back

**Operational tier (03:00) — rotating, local-only (staged into `k8s-dumps-op/`):**

**PostgreSQL databases:**
- `miniflux`, `teslamate`, `authentik` on [[postgresql]] (blumeops-pg)
- `immich` on immich-pg

**K8s SQLite databases (pre-backup dump via kubectl exec):**
- [[mealie]] - Recipe manager (`/app/data/mealie.db`)

**K8s service-produced backup files (newest ferried off the PVC):**
- [[navidrome]] - music DB: users, play counts, playlists (navidrome's own `ND_BACKUP_*` snapshot in `/data/backup`)
- audiobookshelf - built-in scheduled backup of config+metadata (`/metadata/backups`)
- pulumi-stack-backup — Pulumi Cloud stack state, one ferry each for the two stacks `tail8d86e` and `eblu-me` (`pulumi stack export --show-secrets`; the ringtail dump endpoint reads straight off the PV — a missing or empty export keeps the previous staged file; exports contain plaintext secret values — borg repo encryption is the control; restore: [[restore-pulumi-state]])

talos — session transcripts + service state (`/home/talos/data`), owned by its own config (`talos-data.yaml`); see "Talos session state" below.

The SQLite snapshots and ferried backup files above are staged by a
`commands:` hook with `before: configuration` in each tier config, so they run
**once per backup run** rather than once per repository. A non-zero exit from
any hook aborts the whole run — a failed snapshot is never silently skipped.
The archive config (02:00) stages its never-lose dumps (heph.db, forgejo.db,
horkos.db, paperless-media.tar) into `~/.local/share/borgmatic/k8s-dumps-archive/`
(a source of that config); the operational config (03:00) stages its subset
(mealie, navidrome, audiobookshelf, pulumi) into `~/.local/share/borgmatic/k8s-dumps-op/`
(a source of the operational config).

**Immich photo library** (separate config, BorgBase offsite only):
- `/Volumes/photos/library` and `/Volumes/photos/upload` (sifaka SMB mount, ~128 GB); excludes `encoded-video/`, `thumbs/`, `backups/` — regenerable from originals

**Talos session state** (separate config, never pruned — confirmed tier, eblume/blumeops#1417):
- `/home/talos/data` — every agent session ever (transcripts, service state, `session-index.sqlite`), in-pod tar → `~/.local/share/borgmatic/k8s-dumps-talos/talos-data.tar`, `talos-data-*` archives in the same two repos. The config has no `keep_*` keys by design, and the main config's `match_archives: 'indri-*'` keeps any future prune off the prefix (heph 01M0GA6JPGQF96AM5JZKA37YSV). Measured cost (eblume/blumeops#1409, 2026-10-05): 79.6 MB/night deduplicated, ~2.4 GB/month per repo (~25% of nightly growth) — decision: stays never-pruned, with `compression: auto,zstd` on the config (new chunks only). Single-session restore: [[backups]] → "Restoring a Single Session" (reaped/tombstoned sessions: "Restoring a Reaped (Tombstoned) Session").

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
- **Sampled test-restore** — when `/Volumes/photos` (the [[sifaka]] SMB mount) is mounted: 5 random regular files >1 MB from the newest archive are extracted via `borg extract --stdout` and sha256-compared against the live files under `/Volumes/photos`. A hash **mismatch fails the run** (benign when the live file changed after the last 04:00 backup). Transient per-file problems, a file deleted from sifaka since the backup or an `extract` failure (ssh blip), are **skipped** with a reason in the logs. A **permission error (EPERM/EACCES) on the live read fails the run and writes no marker**: a permission error is the TCC regression this job exists to catch, and skipping it (with some other file still comparing) would let a TCC regression land a marker and go silent. The `compared`/`skipped`/`mismatched` counts are exported as metrics below so a run that mostly skips is visible; the marker is written only when at least one file was actually compared.

Every result lands in the Loki-tailed logs
(`mcquack.borgmatic-verify-photos.{out,err}.log`). Success markers are written
to `/opt/homebrew/var/state/borgmatic-verification/` (`check`, `check-data`,
`test-restore`, plus the per-run `test-restore-compared` / `-skipped` /
`-mismatched` counts) and exposed by the hourly collector as
`borgmatic_last_verified_timestamp{repo="borgbase-immich-photos"}`,
`borgmatic_last_verified_data_timestamp{repo="borgbase-immich-photos"}`,
`borgmatic_last_test_restore_timestamp{repo="borgbase-immich-photos"}`, and the
counts as `borgmatic_test_restore_compared_files`,
`borgmatic_test_restore_skipped_files`, and
`borgmatic_test_restore_mismatched_files`.

**The live read runs under a TCC-granted responsible binary.** The
LaunchAgent's `ProgramArguments[0]` is the pipx venv python, the same
interpreter the create agents use to read `/Volumes/photos` and the identity
that holds the macOS Network Volumes grant, which launches the role's bash
verification script as a subprocess. `bash` and its `shasum` children inherit
that (granted) responsibility, so the live read is attributed to the granted
binary. If the agent instead exec'd the `#!/bin/bash` script directly, the
responsible process would be `/bin/bash` (no grant) and the live `shasum` over
the SMB mount would fail with EPERM, which is exactly what the
EPERM-fails-the-run handling above catches. If a TCC grant is ever missing, the
one-time fallback is granting that venv python *Network Volumes* in System
Settings (never `/bin/bash`).

The `BorgmaticVerifyStale` Grafana alert fires when no check succeeds for 10
days. `BorgmaticTestRestoreStale` fires when no successful test restore is
recorded for 14 days; unlike `BorgmaticVerifyStale` it uses `noDataState:
Alerting`, because a missing series *is* the failure (a restore that has never
succeeded).

**Verification proves the archives can be read and restored — it does NOT prove immutability.** Both BorgBase repos' keys (`borgmatic@indri`, on `immich-photos` and `indri-borgmatic`) are server-side append-only, confirmed from the dashboard 2026-10-13, which protects the offsite copies from a compromised indri; but the sifaka-local mount `/Volumes/backups/borg` is an SMB share, not a `borg serve` endpoint, so its client-side `append_only` flag protects nothing against indri itself.

## Key escrow

All four repositories are `repokey`-encrypted with one shared passphrase (each
config's `encryption_passcommand` reads indri's `~/.borg/config.yaml`). The key
lives inside the repository, so day-to-day recovery needs only the passphrase,
which is handwritten on the physical Emergency Kit ("Backup Archive Password").
The handwritten copy is deliberate: the 1Password encrypted export is archived
inside these same borg repos, so a borg secret kept only in 1Password would be
out of reach if 1Password were lost.

As insurance against a damaged stored key, the `borg key export --paper` output
for all four repositories lives in 1Password (the "borg backup" and "borgbase"
items, matched by repository ID), not on the physical kit. Confirmed for all
four repositories on 2026-10-13 (#1417); the shared passphrase was
hash-compared against indri's `~/.borg/config.yaml` and the 1Password "borg
backup" password the same day.

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
