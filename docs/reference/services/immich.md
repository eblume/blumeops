---
title: Immich
modified: 2026-09-04
last-reviewed: 2026-03-23
tags:
  - service
  - media
---

# Immich

Self-hosted photo and video management.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://photos.ops.eblu.me |
| **Public URL** | https://photos.eblu.me (shared-link surface only — [[photos-public-sharing]]) |
| **Namespace** | `immich` |
| **Version** | v3.0.2 (upgraded from v2.6.3 on 2026-07-14) |
| **Deployment** | Kustomize (k8s) — `argocd/manifests/immich-ringtail/` |
| **Database** | [[postgresql]] (CNPG), VectorChord-backed |
| **Storage** | [[sifaka|Sifaka]] photos volume (NFS) |

Image tags live in `argocd/manifests/immich-ringtail/kustomization.yaml`
(`immich-server` + `immich-machine-learning:*-cuda` bump together).

## Database & Vector Extension

The immich Postgres (`immich-pg` in the `databases` namespace) runs the
`ghcr.io/tensorchord/cloudnative-vectorchord` image with `vchord.so`
preloaded. immich hard-gates on extension versions at startup and refuses
to boot if they fall outside its supported range, so this matters at
upgrade time:

- **VectorChord** (`vchord`) — currently 0.5.0; immich v3.0.2 accepts `>=0.3 <2`.
- **pgvector** (`vector`) — currently 0.8.0; v3.0.2 accepts `>=0.5 <1`.

immich v3.0.0 **dropped pgvecto.rs** in favor of VectorChord; ringtail was
already on VectorChord (from the [[immich-pg-data-migration]] cutover), so
the v3 upgrade was a plain image-tag bump. Never point immich at a DB image
offering an **older** vchord/pgvector than what's installed — the downgrade
guard blocks startup.

## Related

- [[photos-public-sharing]] - Public family album sharing over the shared-link surface only
- [[postgresql]] - Database backend
- [[sifaka|Sifaka]] - Photo storage
- [[jellyfin]] - Video streaming (separate service)
