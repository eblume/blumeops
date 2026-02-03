---
id: borgmatic-log
tags:
- blumeops
---

# Borgmatic Management Log

Borgmatic runs daily backups from Indri to Sifaka NAS using Borg backup.

## Service Details

- Installed via: mise (pipx)
- Config: `~/.config/borgmatic/config.yaml` (ansible-managed)
- Schedule: Daily at 2:00 AM via LaunchAgent
- Repository: `/Volumes/backups/borg/` on Sifaka

## What Gets Backed Up

**Directories:**
- `~/code/personal/zk` - Zettelkasten (primary)
- `/opt/homebrew/var/forgejo` - Git forge data
- `~/.config/borgmatic` - Borgmatic config itself
- `~/Documents` - Personal documents
- `~/Pictures` - Photos (see note below)

**Note on iCloud Photos:** macOS Photos.app defaults to "Optimize Mac Storage" which keeps only thumbnails locally. Borgmatic only backs up what's on disk, so iCloud-only photos are NOT backed up. If you need full photo backups via borgmatic, either disable "Optimize Mac Storage" in Photos preferences, or use a tool like osxphotos which forces downloads. See log entry 2026-01-28.

**Databases:**
- `miniflux` PostgreSQL database on k8s CloudNativePG cluster (pg.ops.eblu.me)
- `teslamate` PostgreSQL database on k8s CloudNativePG cluster (pg.ops.eblu.me)

**Not backed up (by design):**
- ZIM archives in `~/transmission/` - re-downloadable via torrent
- Prometheus metrics - ephemeral data
- Loki logs - ephemeral (now in k8s PVC)
- devpi data - in k8s PVC, backup strategy TBD

## PostgreSQL Backup

Borgmatic uses native `postgresql_databases` support to stream `pg_dump` directly to Borg:
- No intermediate files needed
- Database keeps running (no downtime)
- Consistent transactional snapshots
- Uses `borgmatic` user with `pg_read_all_data` role
- Password read from `~/.pgpass` (managed by borgmatic ansible role)
- Uses explicit `pg_dump_command` path (`/opt/homebrew/opt/postgresql@18/bin/pg_dump`) since LaunchAgent doesn't have homebrew in PATH
- Uses explicit `local_path` (`/opt/homebrew/bin/borg`) for same reason

**Databases backed up:**
- `pg.ops.eblu.me:5432/miniflux` - CloudNativePG cluster in k8s
- `pg.ops.eblu.me:5432/teslamate` - CloudNativePG cluster in k8s

## Ansible Management

Borgmatic is fully managed via ansible in [[1767747119-YCPO|blumeops]]:

```bash
mise run provision-indri -- --tags borgmatic
```

The role deploys:
- `~/.config/borgmatic/config.yaml` - Main configuration
- LaunchAgent plist for scheduled runs

## Useful Commands

```bash
# List archives
ssh indri 'mise x -- borgmatic list'

# Extract from latest archive
ssh indri 'mise x -- borgmatic extract --archive latest --path /some/path'

# Run backup manually
ssh indri 'mise x -- borgmatic create --verbosity 1'

# Check repository health
ssh indri 'mise x -- borgmatic check'
```

## Retention Policy

- 7 daily backups
- 12 monthly backups
- 1000 yearly backups (effectively forever)

## Monitoring

Borgmatic metrics are collected hourly via a script at `~/bin/borgmatic-metrics` and exposed to Prometheus via the node_exporter textfile collector.

View the Grafana dashboard at: https://grafana.tail8d86e.ts.net (select "Borgmatic Backups" dashboard)

Metrics include:
- `borgmatic_up` - repository accessibility
- `borgmatic_repo_deduplicated_size_bytes` - actual disk usage
- `borgmatic_last_archive_original_size_bytes` - size of data being backed up
- `borgmatic_last_archive_deduplicated_size_bytes` - new data added per backup
- `borgmatic_archive_count` - number of archives
- `borgmatic_last_archive_timestamp` - when last backup ran

```bash
# Check metrics file
ssh indri 'cat /opt/homebrew/var/node_exporter/textfile/borgmatic.prom'

# Check metrics LaunchAgent status
ssh indri 'launchctl list | grep borgmatic-metrics'
```

## Log

### Tue Jan 28 2026

- Investigated massive backup size increase (~69GB deduplicated, ~94GB per archive)
- Root cause: immich-sync role (added Jan 26, removed Jan 28) used osxphotos to export photos
- **Lesson learned:** osxphotos forces Photos.app to download all iCloud originals locally
- Photos.app defaults to "Optimize Mac Storage" which keeps only thumbnails locally
- Before immich-sync: borgmatic was backing up thumbnails (~few GB)
- After immich-sync: borgmatic now has full 42GB of photo originals
- This is actually a bonus - provides redundant photo backup alongside iCloud and Immich
- Retention policy means these photos will be kept in yearly archives essentially forever
- **Future plan:** Once Immich (on sifaka "photos" volume with Synology offsite backup) is fully set up, Pictures may be removed from borgmatic as redundant

### Thu Jan 23 2026

- Note: Forgejo `app.ini` is now managed by ansible (secrets in 1Password)
- `/opt/homebrew/var/forgejo` still backed up for git repositories and data
- But `app.ini` recovery no longer depends on borgmatic (can be regenerated via ansible)

### Wed Jan 22 2026

- Removed `/opt/homebrew/var/loki` from backup sources (stale data from pre-k8s migration)
- Loki now runs in k8s with ephemeral storage - logs are not backed up by design
- Verified backup integrity after cleanup

### Mon Jan 20 2026 (P5)

- Removed `~/devpi` from backup sources (devpi migrated to k8s)
- devpi data now in k8s PVC - backup strategy TBD

### Sun Jan 19 2026 (P4)

- Removed localhost PostgreSQL backup (brew pg retired)
- Updated to backup only `pg.tail8d86e.ts.net` (k8s CloudNativePG)
- Moved .pgpass management from postgresql role to borgmatic role

### Sun Jan 19 2026 (P3)

- Fixed borgmatic failing to find `borg` binary by adding `local_path` option to config
- Added k8s-pg (CloudNativePG cluster) backup alongside brew PostgreSQL
- Added ACL grant for `tag:homelab` → `tag:k8s` on port 5432 for backup access
- Successfully tested disaster recovery: restored miniflux data from borgmatic dump to k8s-pg
- Created `borgmatic` user in k8s-pg via CloudNativePG managed roles
- Both localhost and k8s-pg databases backed up during migration period

### Sat Jan 18 2026

- Fixed borgmatic-metrics script failing in LaunchAgent context by using absolute paths (`/opt/homebrew/bin/borg`, `/opt/homebrew/bin/jq`) instead of `mise x -- borg`
- This was causing the Grafana dashboard to show "Repository Status: DOWN" and missing time series data

### Fri Jan 17 2026

- Fixed PostgreSQL backup failure by adding explicit `pg_dump_command` path (was failing with "pg_dump: command not found")
- Removed `~/code/3rd/kiwix-tools` from backups (was just symlinks, ZIM archives are re-downloadable)
- Enabled Loki log backup (removed from exclude_patterns)
- Added borgmatic_metrics role for Prometheus metrics collection
- Added Grafana dashboard for backup monitoring (size trends, dedup ratio, time since last backup)

### Thu Jan 16 2026

- Moved config from manual management to ansible-managed template
- Added `postgresql_databases` backup for miniflux database
- Config now deployed via `ansible/roles/borgmatic/templates/config.yaml.j2`
