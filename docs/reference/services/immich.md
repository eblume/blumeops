---
title: Immich
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
| **Namespace** | `immich` |
| **Deployment** | Helm chart (k8s) |
| **Database** | [[services/postgresql|PostgreSQL]] (CNPG) |
| **Storage** | [[storage/sifaka|Sifaka]] photos volume |

## Related

- [[services/postgresql|PostgreSQL]] - Database backend
- [[storage/sifaka|Sifaka]] - Photo storage
- [[services/jellyfin|Jellyfin]] - Video streaming (separate service)
