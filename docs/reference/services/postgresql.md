---
title: PostgreSQL
modified: 2026-02-15
tags:
  - service
  - database
---

# PostgreSQL

Database clusters via CloudNativePG operator.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | `tcp://pg.ops.eblu.me:5432` |
| **Metrics** | `http://cnpg-metrics.tail8d86e.ts.net:9187/metrics` |
| **Namespace** | `databases` |
| **Clusters** | `blumeops-pg`, `immich-pg` |
| **Operator** | CloudNativePG |

## Databases

| Database | Cluster | Owner | Purpose |
|----------|---------|-------|---------|
| miniflux | blumeops-pg | miniflux | [[miniflux]] feed data |
| teslamate | blumeops-pg | teslamate | [[teslamate]] vehicle data |
| immich | immich-pg | immich | [[immich]] photo management |

The `immich-pg` cluster uses a custom image (`cloudnative-vectorchord`) with vector search extensions (vector, vchord, cube, earthdistance).

## Users

| User | Role | Purpose |
|------|------|---------|
| postgres | superuser | CNPG internal |
| miniflux | app owner | Owns miniflux database |
| teslamate | superuser | TeslaMate (needs extensions) |
| eblume | superuser | Admin access |
| borgmatic | pg_read_all_data | [[borgmatic|Backup]] access |

## Backup

Backed up via [[borgmatic]] `postgresql_databases` hook. Streams `pg_dump` directly to Borg (no intermediate files, no downtime). See [[backup]] for overall backup policy.

## Credentials

**1Password items:**
- `guxu3j7ajhjyey6xxl2ovsl2ui` - eblume password
- `mw2bv5we7woicjza7hc6s44yvy` - borgmatic password

**CNPG-managed secrets (blumeops-pg):**
- `blumeops-pg-app` - miniflux user
- `blumeops-pg-eblume` - eblume superuser
- `blumeops-pg-borgmatic` - borgmatic backup user
- `blumeops-pg-teslamate` - teslamate user

**CNPG-managed secrets (immich-pg):**
- `immich-pg-app` - immich user

## Related

- [[connect-to-postgres]] - How to connect via psql
- [[miniflux]] - Feed reader database
- [[teslamate]] - Vehicle data database
- [[immich]] - Photo management database
- [[borgmatic]] - Database backup
