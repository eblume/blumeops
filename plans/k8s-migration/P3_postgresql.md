# Phase 3: PostgreSQL Migration

**Goal**: Migrate miniflux database to CloudNativePG

**Status**: Pending

**Prerequisites**: [Phase 2](P2_grafana.md) complete

---

## Steps

### 1. Create databases and users in k8s PostgreSQL

- miniflux database/user
- borgmatic read-only user

---

### 2. Export from brew PostgreSQL

```bash
pg_dump -h localhost -U miniflux miniflux > miniflux_backup.sql
```

---

### 3. Expose k8s PostgreSQL via Tailscale

- Service with `loadBalancerClass: tailscale`
- Tag: `svc:pg-k8s`

---

### 4. Import data

```bash
psql -h pg-k8s.tail8d86e.ts.net -U miniflux miniflux < miniflux_backup.sql
```

---

### 5. Update borgmatic config

- Change hostname to k8s PostgreSQL

---

### 6. Verify data integrity

---

## Rollback

Keep brew PostgreSQL running until Phase 4 verified
