---
title: Connect to Postgres
modified: 2026-02-15
last-reviewed: 2026-02-15
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
PGPASSWORD=$(op read "op://blumeops/postgres/password") psql -h pg.ops.eblu.me -U eblume -d postgres
```

This connects as the `eblume` superuser. To connect to a specific database, replace `postgres` with the database name (e.g. `miniflux`, `teslamate`).

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
