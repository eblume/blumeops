---
title: Jellyfin
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

## Observability

- Metrics: `jellyfin_metrics` ansible role
- Logs: Forwarded via [[Grafana Alloy|Alloy]]
- Dashboard: "Jellyfin Media Server" in [[Grafana]]

## Related

- [[Navidrome]] - Music streaming
- [[Sifaka NAS|Sifaka]] - Media storage
