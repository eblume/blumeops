---
title: Connect to Postgres
modified: 2026-09-11
last-reviewed: 2026-09-11
tags:
  - how-to
  - database
---

# Connect to Postgres

How to connect to the [[postgresql]] cluster as a superuser using `psql`.

## Prerequisites

- `psql` installed (`brew install libpq` on macOS)
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`) installed and signed in
- Machine on the tailnet (e.g. [[gilbert]])

## Connect

```bash
PGPASSWORD=$(op read "op://blumeops/postgres/password") psql -h pg.ops.eblu.me -p 5434 -U eblume -d postgres
```

Each cluster gets its own Caddy L4 port on the tailnet — `pg.ops.eblu.me:5434` is `blumeops-pg`, `:5433` is `immich-pg`. The old `:5432` route retired with the minikube cluster ([[retire-minikube]] phase 5). This connects as the `eblume` superuser; to connect to a specific database, replace `postgres` with the database name (e.g. `miniflux`, `teslamate`).

## Useful Queries

```sql
-- List databases
\l

-- List roles
\du

-- Check cluster status (CNPG)
SELECT pg_is_in_recovery();

-- Show active connections
SELECT datname, usename, client_addr, state
FROM pg_stat_activity
WHERE state IS NOT NULL;
```

## Related

- [[postgresql]] - Service reference
- [[borgmatic]] - Database backup
- [[troubleshooting]] - Cluster health checks
