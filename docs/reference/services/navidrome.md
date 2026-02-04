---
title: navidrome
tags:
  - service
  - media
---

# Navidrome

Self-hosted music streaming server.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://dj.ops.eblu.me |
| **Tailscale URL** | https://dj.tail8d86e.ts.net |
| **Namespace** | `navidrome` |
| **Manifests** | `argocd/manifests/navidrome/` |

## Storage

| Mount | Type | Source | Access |
|-------|------|--------|--------|
| /music | NFS PV | sifaka:/volume1/music | Read-only |
| /data | Local PVC (10Gi) | minikube storage | Read-write |

The `/data` directory contains SQLite database, configuration, and cache.

## Configuration

| Variable | Value |
|----------|-------|
| `ND_SCANSCHEDULE` | 1h |
| `ND_LOGLEVEL` | info |
| `ND_MUSICFOLDER` | /music |
| `ND_DATAFOLDER` | /data |

## Related

- [[jellyfin]] - Video streaming
- [[sifaka | Sifaka]] - Music storage
