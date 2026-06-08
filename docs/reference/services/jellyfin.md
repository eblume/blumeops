---
title: Jellyfin
modified: 2026-06-08
last-reviewed: 2026-06-08
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

Installed via Homebrew cask (`state: present`, unpinned), so the Ansible role
won't bump an already-installed cask. To upgrade, run on indri:

```bash
brew upgrade --cask jellyfin
```

**Gatekeeper gotcha:** a cask upgrade replaces `/Applications/Jellyfin.app` and
re-applies the `com.apple.quarantine` xattr. When launchd respawns the service,
the new binary hangs silently — process alive but ~0 CPU, no logs, no listening
socket — because Gatekeeper is holding the first launch pending approval.
Removing the xattr over SSH fails (`xattr -dr com.apple.quarantine ...` →
"Operation not permitted", blocked by macOS TCC). Approve the first-launch
dialog on indri's GUI console (or run the `xattr` removal from a local Terminal
with Full Disk Access), then reload the LaunchAgent.

## Observability

- Metrics: `jellyfin_metrics` ansible role
- Logs: Forwarded via [[alloy|Alloy]]
- Dashboard: "Jellyfin Media Server" in [[grafana]]

## Related

- [[navidrome]] - Music streaming
- [[sifaka|Sifaka]] - Media storage
