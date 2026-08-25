---
title: Jellyfin
modified: 2026-08-24
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
| **Media** | `/Volumes/allisonflix` (NFS from sifaka) |
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

Pinned in `ansible/roles/jellyfin/defaults/main.yml` (`jellyfin_version` +
`jellyfin_release_sha256`). The role downloads the official release DMG from
repo.jellyfin.org into `~/opt/jellyfin-<version>/` and uninstalls the Homebrew
cask, so `brew upgrade` no longer touches Jellyfin and the Gatekeeper
re-quarantine gotcha does not apply (quarantine is stripped at deploy time,
in the home directory where SSH is not TCC-blocked).

To upgrade:

1. Bump `jellyfin_version` and `jellyfin_release_sha256` in a blumeops PR
   (the sha256 is the one Homebrew's cask formula publishes for the same DMG).
2. On merge: `mise run provision-indri -- --tags jellyfin` from a machine
   with indri SSH and 1Password access.

## Observability

- Metrics: `jellyfin_metrics` ansible role
- Logs: Forwarded via [[alloy|Alloy]]
- Dashboard: "Jellyfin Media Server" in [[grafana]]

## Related

- [[navidrome]] - Music streaming
- [[sifaka|Sifaka]] - Media storage
