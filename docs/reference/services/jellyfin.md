---
title: Jellyfin
modified: 2026-11-02
last-reviewed: 2026-08-24
tags:
  - service
  - media
---

# Jellyfin

Open-source media server running natively on indri for VideoToolbox hardware transcoding.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://jellyfin.ops.eblu.me |
| **Local Port** | 8096 |
| **Data** | `~/Library/Application Support/jellyfin` |
| **Media** | `/Volumes/allisonflix` (SMB from sifaka) |
| **LaunchAgent** | `mcquack.jellyfin` |

## Hardware Transcoding

Apple VideoToolbox on M1 Mac Mini.

| Codec | Support |
|-------|---------|
| H.264 encode/decode | Hardware |
| HEVC (H.265) encode/decode | Hardware |
| AV1 decode | Software (requires M3+) |
| HDR to SDR tone mapping | VPP (hardware) |

Concurrent 4K streams with HDR tonemapping: ~3

## Configuration

Dashboard > Playback:
1. Hardware Acceleration: Apple VideoToolbox
2. Allow hardware encoding: Enabled
3. VPP Tone mapping: Enabled

## Upgrades

Pinned in `darwin/indri/jellyfin-pins.yaml` (`jellyfin_version` +
`jellyfin_release_sha256`). The `darwin/indri` generation downloads the official release DMG from
repo.jellyfin.org into `~/opt/jellyfin-<version>/`. The Homebrew cask was
uninstalled by the retired ansible role and the generation does not manage it,
so `brew upgrade` no longer touches Jellyfin and the Gatekeeper
re-quarantine gotcha does not apply (quarantine is stripped at deploy time,
in the home directory where SSH is not TCC-blocked).

To upgrade within a major:

1. Bump `jellyfin_version`, `jellyfin_release_url` and `jellyfin_release_sha256` in
   `darwin/indri/jellyfin-pins.yaml` in a blumeops PR (the sha256 is the one Homebrew's
   cask formula publishes for the same DMG).
2. On merge: the generation's postActivation installs the new version side by side,
   repoints `jellyfin-current` and restarts the agent once. A sha256 mismatch fails
   closed: the running version is kept.

### 12.x major upgrade (10.11.11 → 12.4)

Pre-upgrade gates and the deploy. Nothing here is automated; the `[human]`
items are tracked in the Human steps of blumeops#2193.

- **One-way migrations.** 12.0 DB migrations cannot be rolled back without a
  restore. Rollback is the backup below, not a version downgrade. A full
  library scan is required after the first start.
- **Backup (DB, config, metadata, plugins; no media, no caches).** With
  Jellyfin stopped, copy `~/Library/Application Support/jellyfin/{data,config,metadata,plugins}`
  from indri, skipping the trickplay and chapter-image subfolders under
  `metadata/` (they regenerate). Exclude `cache/` and `log/`. Media lives on
  sifaka at `/Volumes/allisonflix` and is not under this path.
- **Media baseline.** Before the first 12.x start, record every media file
  (path and size) under `/Volumes/allisonflix`. After the first full scan,
  every file must still be present at the same size. No existing media file
  may be deleted, moved, or renamed. NFO and artwork sidecars may be replaced,
  so the manifest filters to media extensions (mkv, mp4, m4v, avi, srt, ass).
- **Series timers with KeepUpTo.** Confirm no series timer on sifaka has
  KeepUpTo set. Recording cleanup deletes files on that path and is not
  covered by the upgrade's media check.
- **Third-party plugins.** 12.0 requires third-party plugins removed before the
  first start. The generation removes every other `SSO-Auth_*` directory (the 9p4
  `4.0.0.3` copy, .NET 9, targets 10.11) and installs `SSO-Auth_5.1.0.0` (K0lin
  fork, same plugin GUID, targets 12.0).
- **Legacy routes and auth.** `/emby/*` and `/mediabrowser/*` are removed, and
  legacy auth is off by default. The metrics script and the Homepage widget use
  `/System/Info`, `/Library/VirtualFolders`, and `/health` with an API key or
  `X-Emby-Token`. Confirm both still return data after the upgrade.
- **Post-deploy check.** An Authentik (SSO) login must work. If it does not,
  roll back: stop Jellyfin, restore `data/`, `config/`, `metadata/`, and
  `plugins/` from the backup, and revert this PR's pin change. The generation
  repoints `jellyfin-current` at the kept `~/opt/jellyfin-10.11.11` install on the
  next apply. Rollback needs a restore because 12.x migrations are one-way.

## Observability

- Metrics: the `mcquack.eblume.jellyfin-metrics` user agent (nix-managed; reads the API key from `~/.config/metrics-keys/jellyfin-api-key`, seeded by `seed-secrets`)
- Logs: Forwarded via [[alloy|Alloy]]
- Dashboard: "Jellyfin Media Server" in [[grafana]]

## Related

- [[navidrome]] - Music streaming
- [[sifaka|Sifaka]] - Media storage
