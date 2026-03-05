---
title: Kiwix
modified: 2026-03-05
tags:
  - service
  - knowledge
---

# Kiwix

Offline Wikipedia and ZIM archive server.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://kiwix.ops.eblu.me |
| **Tailscale URL** | https://kiwix.tail8d86e.ts.net |
| **Namespace** | `kiwix` |
| **Image** | `registry.ops.eblu.me/blumeops/kiwix-serve:v3.8.2` |
| **Storage** | NFS from [[sifaka|Sifaka]] (`/volume1/torrents`) |

## Architecture

| Component | Purpose |
|-----------|---------|
| kiwix-serve | Serves ZIM files on port 80 |
| torrent-sync | Sidecar syncing ZIM torrents to [[transmission]] |
| zim-watcher | CronJob (hourly) to restart on new ZIMs |

## Configured Archives

- Wikipedia top 1M English articles with images
- Project Gutenberg (60,000+ books)
- iFixit repair guides
- Stack Exchange (SuperUser, Math, etc.)
- LibreTexts textbooks
- DevDocs developer documentation

Full list: `argocd/manifests/kiwix/torrents.txt`

## Adding Archives

1. Edit `configmap-zim-torrents.yaml`
2. Add torrent URL from https://download.kiwix.org/zim/
3. Sync: `argocd app sync kiwix`
4. Torrent-sync adds to [[transmission]]
5. zim-watcher restarts kiwix when download completes

## Related

- [[transmission]] - Downloads ZIM files
- [[sifaka|Sifaka]] - ZIM storage
