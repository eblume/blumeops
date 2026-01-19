# Phase 5: devpi Migration

**Goal**: Migrate devpi to k8s

**Status**: Pending

**Prerequisites**: [Phase 4](P4_miniflux.md) complete

---

## Steps

### 1. Build devpi container

- Dockerfile with devpi-server + devpi-web
- Push to local Zot registry

---

### 2. Deploy as StatefulSet

- PVC for data (50Gi)
- Migrate existing data (excluding PyPI cache)

---

### 3. Configure Tailscale LoadBalancer

Tag: `svc:pypi`

---

### 4. Update pip.conf on gilbert

---

### 5. Stop mcquack devpi
