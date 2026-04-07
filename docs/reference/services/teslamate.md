---
title: TeslaMate
modified: 2026-04-07
last-reviewed: 2026-03-23
tags:
  - service
  - vehicle
---

# TeslaMate

Self-hosted Tesla data logger collecting vehicle telemetry from the Tesla API.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://tesla.ops.eblu.me |
| **Namespace** | `teslamate` |
| **Image** | `registry.ops.eblu.me/blumeops/teslamate` (see `argocd/manifests/teslamate/kustomization.yaml` for current tag) |
| **Database** | [[postgresql]] |

## Data Collected

- Battery level, state of charge, range estimates
- Charging sessions (location, energy, cost, duration)
- Drives (distance, efficiency, routes)
- Climate/HVAC usage
- Software update history
- Vampire drain analysis
- Vehicle states (asleep, driving, charging, online)

## Grafana Dashboards

18 dashboards in the "TeslaMate" folder:
- Overview, Charges, Drives, Efficiency, States
- Battery Health, Vampire Drain, Statistics
- Charge Level, Locations, Trip, Mileage
- Drive Stats, Charging Stats, Projected Range
- Timeline, Updates, Visited

Dashboards use PostgreSQL datasource (not Prometheus). The Grafana datasource connects as the `teslamate` database user.

## Database Permissions

The `teslamate` role was initially provisioned as superuser to allow extension creation (`cube`, `earthdistance`) during initial setup. Superuser has been removed — `teslamate` is now a plain database owner with extension ownership transferred so it can `ALTER EXTENSION ... UPDATE` without superuser.

Note: `earthdistance` is not a trusted extension in PostgreSQL, so `CREATE EXTENSION earthdistance` still requires superuser. If a future TeslaMate migration does `DROP EXTENSION ... CASCADE` + re-create (as happened in the 2024 migration), it will fail. In that case, temporarily grant superuser for the migration and remove it afterward.

Extension ownership persists across pod restarts and CNPG failovers, but a full cluster rebuild (major PG upgrade, fresh `initdb`) would re-create extensions as `postgres`. After any rebuild, transfer ownership back:

```sql
UPDATE pg_extension SET extowner = (SELECT oid FROM pg_roles WHERE rolname = 'teslamate') WHERE extname IN ('cube', 'earthdistance');
```

## Authentication

Uses Tesla Owner API via OAuth:
1. Access https://tesla.ops.eblu.me
2. Click "Sign in with Tesla"
3. Tokens encrypted with ENCRYPTION_KEY

## Credentials

**1Password:** `TeslaMate` item with `db_password` and `api_enc_key`

## Related

- [[postgresql]] - Data storage
- [[grafana]] - Dashboards
- [[borgmatic]] - Database backup
