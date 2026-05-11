---
title: Shower App
modified: 2026-05-10
last-reviewed: 2026-05-10
tags:
  - service
  - django
---

# Shower App

Django web app for Adelaide / Heidi / Addie's baby shower — guest splash with
a "what did you bring?" form, raffle picker, contest-prize ranking via
QR-coded `/prizes/<token>/` URLs, and an `/host/` operator console with
drag-rank assignment solving via scipy.

## Quick Reference

| Property | Value |
|----------|-------|
| **Public URL** | `shower.eblu.me` (guest surface only — via [[flyio-proxy]]) |
| **Private URL** | `shower.ops.eblu.me` (admin + `/host/` console — Caddy on indri) |
| **Cluster** | [[ringtail]] k3s, namespace `shower` |
| **Container** | `registry.ops.eblu.me/blumeops/shower` (built from `containers/shower/default.nix`) |
| **App source** | `forge.eblu.me/eblume/adelaide-baby-shower-app` (wheel on Forgejo PyPI) |
| **Database** | SQLite on a local-path PVC (`shower-data`, RWO 2 Gi) |
| **Media (prize photos)** | NFS RWX PVC `shower-media` → `sifaka:/volume1/shower` |
| **Secrets** | `Shower (blumeops)` 1Password item → `DJANGO_SECRET_KEY` |

## Routing

```
Internet → shower.eblu.me  (Fly nginx, guest-only 403s on /admin/ /host/)
            │
            ▼
        Caddy on indri (shower.ops.eblu.me — full surface)
            │
            ▼
        Tailscale ProxyGroup → k3s Service → Deployment
```

## Backups

- **SQLite** dumped via `kubectl exec` to indri's `borgmatic_k8s_dump_dir` on every 2 a.m. run (mealie-pattern entry in `borgmatic_k8s_sqlite_dumps`)
- **Media** picked up via `/Volumes/shower` (sifaka SMB mount on indri) in the main `borgmatic_source_directories` list

Both archive to sifaka + BorgBase.

## Related

- [[shower-on-ringtail]] — onboarding + day-of runbook
- [[expose-service-publicly]] — Fly proxy + tailnet pattern this rides on
- [[ringtail]] — host cluster
- [[sifaka#NFS Exports]] — NFS share table
- [[borgmatic]] — backup system
