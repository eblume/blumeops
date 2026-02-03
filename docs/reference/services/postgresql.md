---
title: PostgreSQL
tags:
  - service
  - database
---

# PostgreSQL

Database cluster via CloudNativePG operator.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | `tcp://pg.ops.eblu.me:5432` |
| **Metrics** | `http://cnpg-metrics.tail8d86e.ts.net:9187/metrics` |
| **Namespace** | `databases` |
| **Cluster** | `blumeops-pg` |
| **Operator** | CloudNativePG |

## Databases

| Database | Owner | Purpose |
|----------|-------|---------|
| miniflux | miniflux | [[miniflux|Miniflux]] feed data |
| teslamate | teslamate | [[teslamate|TeslaMate]] vehicle data |

## Users

| User | Role | Purpose |
|------|------|---------|
| postgres | superuser | CNPG internal |
| miniflux | app owner | Owns miniflux database |
| teslamate | superuser | TeslaMate (needs extensions) |
| eblume | superuser | Admin access |
| borgmatic | pg_read_all_data | [[borgmatic|Backup]] access |

## Backup

Backed up via [[borgmatic|Borgmatic]] `postgresql_databases` hook. Streams `pg_dump` directly to Borg (no intermediate files, no downtime). See [[backup|Backup]] for overall backup policy.

## Credentials

**1Password items:**
- `guxu3j7ajhjyey6xxl2ovsl2ui` - eblume password
- `mw2bv5we7woicjza7hc6s44yvy` - borgmatic password

**CNPG-managed secrets:**
- `blumeops-pg-app` - miniflux user
- `blumeops-pg-eblume` - eblume superuser
- `blumeops-pg-borgmatic` - borgmatic backup user
- `blumeops-pg-teslamate` - teslamate user

## Related

- [[miniflux|Miniflux]] - Feed reader database
- [[teslamate|TeslaMate]] - Vehicle data database
- [[borgmatic|Borgmatic]] - Database backup
