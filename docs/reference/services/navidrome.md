---
title: Navidrome
modified: 2026-02-21
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

## Authentication

Local accounts only. Authentik SSO integration was evaluated (Feb 2026) but not pursued — Navidrome lacks native OIDC support. The reverse proxy auth approach (`ND_EXTAUTH_*`) can pass a username header from Authentik, but cannot map Authentik groups to Navidrome admin status, making group-based admin delegation impossible.

## Related

- [[jellyfin]] - Video streaming
- [[sifaka|Sifaka]] - Music storage
