# Phase 4: Miniflux Migration

**Goal**: Migrate Miniflux to k8s

**Status**: Pending

**Prerequisites**: [Phase 3](P3_postgresql.md) complete

---

## Steps

### 1. Deploy Miniflux

```yaml
image: ghcr.io/miniflux/miniflux:latest
env:
  DATABASE_URL: from secret
  RUN_MIGRATIONS: "1"
```

---

### 2. Configure Tailscale LoadBalancer

Tag: `svc:feed`

---

### 3. Update Alloy log collection

Add k8s namespace

---

### 4. Verify

- Login works
- Feeds refresh
- API works

---

### 5. Stop brew miniflux

```bash
brew services stop miniflux
```
