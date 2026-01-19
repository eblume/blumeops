# Phase 9: Cleanup

**Goal**: Remove deprecated services, harden system

**Status**: Pending

**Prerequisites**: [Phase 8](P8_woodpecker.md) complete

---

## Steps

### 1. Stop/remove unused brew services

- postgresql@18
- grafana
- miniflux
- forgejo

---

### 2. Update ansible playbook

- Remove migrated service roles
- Add k8s deployment references

---

### 3. Configure Velero backups (optional)

- Install with MinIO on sifaka
- Schedule daily cluster backups

---

### 4. Update zk documentation

- New architecture
- Runbooks
- DR procedures

---

## Plan Completion

When all phases are complete and verified:

```bash
# Rename this folder to indicate completion
git mv plans/k8s-migration plans/k8s-migration.complete
git commit -m "Complete k8s migration plan"
```
