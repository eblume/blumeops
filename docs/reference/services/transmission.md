---
title: Transmission
modified: 2026-02-07
tags:
  - service
  - torrent
---

# Transmission

BitTorrent daemon, primarily for downloading ZIM archives for [[kiwix]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://torrent.ops.eblu.me |
| **Tailscale URL** | https://torrent.tail8d86e.ts.net |
| **Namespace** | `torrent` |
| **Image** | `lscr.io/linuxserver/transmission:latest` |
| **Storage** | NFS PVC from [[sifaka|Sifaka]] |

## Storage Layout

NFS share on sifaka (`/volume1/torrents`):

| Path | Purpose |
|------|---------|
| `/downloads/` | Active downloads and metadata |
| `/downloads/complete/` | Completed downloads |
| `/config/` | Transmission configuration |
| `/watch/` | Watch directory for .torrent files |

[[kiwix]] reads from `/downloads/complete/` to serve ZIM archives.

## Integration with Kiwix

The Kiwix deployment includes a torrent-sync sidecar that:
1. Reads ZIM torrent list from ConfigMap
2. Adds missing torrents via RPC
3. Runs on startup and every 30 minutes

When downloads complete, the zim-watcher CronJob detects new ZIMs and restarts Kiwix.

## Monitoring

Basic uptime via blackbox probe in [[alloy|Alloy]] k8s (Services Health dashboard).

Web UI shows: active/seeding/paused counts, speeds, disk usage.

## Related

- [[kiwix]] - ZIM archive consumer
- [[sifaka|Sifaka]] - Download storage
