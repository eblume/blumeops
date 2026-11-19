---
title: Transmission
modified: 2026-11-17
last-reviewed: 2026-11-17
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
| **Image** | `registry.ops.eblu.me/blumeops/transmission` |
| **Storage** | NFS PVC from [[sifaka|Sifaka]] |
| **Auth** | RPC auth on; `transmission-rpc` secret (ExternalSecret from 1Password `transmission`). Unauthenticated HTTP, including the web UI, gets 401 |

## Storage Layout

| Path | Backing | Purpose |
|------|---------|---------|
| `/downloads/incomplete/` | NFS (`sifaka:/volume1/torrents`) | Active downloads |
| `/downloads/complete/` | NFS (`sifaka:/volume1/torrents`) | Completed downloads |
| `/config/` | `emptyDir` (ephemeral) | Transmission `settings.json`, regenerated on pod start |

The watch directory is disabled (`watch-dir-enabled: false`); torrents are added via RPC (see Kiwix integration below).

[[kiwix]] reads from `/downloads/complete/` to serve ZIM archives.

## Integration with Kiwix

The Kiwix deployment includes a torrent-sync sidecar that:
1. Reads ZIM torrent list from ConfigMap
2. Adds missing torrents via RPC
3. Runs on startup and every 30 minutes

When downloads complete, the zim-watcher CronJob (hourly) detects new ZIMs and restarts Kiwix.

## Monitoring

A `transmission-exporter` sidecar (image `registry.ops.eblu.me/blumeops/transmission-exporter`) scrapes the local RPC and exposes Prometheus metrics on port 19091. Uptime is also covered by a blackbox probe in [[alloy|Alloy]] k8s (Services Health dashboard). The probe uses the `http_401` module on `/transmission/web/`: 401 is healthy, and a 200 means RPC auth was disabled and alerts.

Web UI shows: active/seeding/paused counts, speeds, disk usage.

## Related

- [[kiwix]] - ZIM archive consumer
- [[sifaka|Sifaka]] - Download storage
