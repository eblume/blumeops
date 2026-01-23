# Phase 3: PostgreSQL Disaster Recovery & Backup

**Goal**: Test disaster recovery and configure borgmatic backups for k8s-pg

**Status**: Complete (2026-01-19)

**Prerequisites**: [Phase 2](P2_grafana.complete.md) complete

---

## Overview

Phase 3 establishes disaster recovery capabilities for the k8s PostgreSQL cluster:
1. **Fix borgmatic backup issues** - Resolve `borg: command not found` error
2. **Test disaster recovery** - Restore miniflux data from borgmatic backup to k8s-pg
3. **Create borgmatic user** - Read-only backup user in k8s-pg via CloudNativePG
4. **Configure dual database backup** - Backup both brew PostgreSQL and k8s-pg during migration

This phase prepares for Phase 4 (miniflux migration) by verifying we can restore data to k8s-pg.

---

## Key Decisions

### Backup Both Databases During Transition

**Decision**: Configure borgmatic to backup both `localhost:5432/miniflux` (brew) and `k8s-pg.tail8d86e.ts.net:5432/miniflux` (k8s) until migration complete.

**Why**: Provides redundancy during migration. After Phase 4, remove localhost entry.

### Reuse Existing borgmatic Password

**Decision**: Use same borgmatic password from 1Password for k8s-pg user.

**Why**: Simpler credential management, password already proven secure.

### CloudNativePG Managed Roles

**Decision**: Declare borgmatic user via CloudNativePG `managed.roles` instead of SQL commands.

**Why**: Declarative, version-controlled, matches eblume user pattern.

### Disable selfHeal on apps App

**Decision**: Remove `selfHeal: true` from `argocd/apps/apps.yaml`.

**Why**: Allows temporarily pointing child apps to feature branches during development without ArgoCD reverting the change.

---

## Steps

### 1. Fix borgmatic borg path issue

**Problem**: borgmatic failing with `borg: command not found`

**Cause**: LaunchAgent doesn't have homebrew in PATH, so `borg` binary not found.

**Solution**: Add `local_path` to borgmatic config template.

**File**: `ansible/roles/borgmatic/templates/config.yaml.j2`
```yaml
# Path to borg binary (LaunchAgent doesn't have homebrew in PATH)
local_path: {{ borgmatic_local_path }}
```

**File**: `ansible/roles/borgmatic/defaults/main.yml`
```yaml
borgmatic_local_path: /opt/homebrew/bin/borg
```

---

### 2. Run manual backup to verify fix

```bash
mise run provision-indri -- --tags borgmatic
ssh indri '/opt/homebrew/bin/borgmatic --verbosity 1'
```

---

### 3. Extract miniflux dump from borgmatic

```bash
ssh indri 'borgmatic list --archive latest'
ssh indri 'borgmatic restore --archive latest --destination /tmp/restore'
```

---

### 4. Add ACL grant for homelab → k8s

**Problem**: Connection from indri to k8s-pg blocked - Tailscale proxy logs showed "no rules matched"

**Solution**: Add ACL grant in Pulumi.

**File**: `pulumi/policy.hujson`
```hujson
// Homelab can reach k8s PostgreSQL for borgmatic backups
{
  "src": ["tag:homelab"],
  "dst": ["tag:k8s"],
  "ip":  ["tcp:5432"],
},
```

Deploy: `mise run tailnet-up`

---

### 5. Restore data to k8s-pg

```bash
# Using eblume superuser credentials from 1Password
ssh indri "psql 'postgres://eblume@k8s-pg.tail8d86e.ts.net:5432/miniflux' -f /tmp/restore/localhost/miniflux/miniflux"
```

**Verification**:
```bash
psql 'postgres://eblume@k8s-pg.tail8d86e.ts.net:5432/miniflux' -c 'SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM feeds; SELECT COUNT(*) FROM entries;'
# Result: 2 users, 2 feeds, 44 entries
```

---

### 6. Create borgmatic user in k8s-pg via CloudNativePG

**File**: `argocd/manifests/databases/secret-borgmatic.yaml.tpl`
```yaml
# Template for borgmatic backup user password
# Apply with: op inject -i secret-borgmatic.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: blumeops-pg-borgmatic
  namespace: databases
type: kubernetes.io/basic-auth
stringData:
  username: borgmatic
  password: {{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/mw2bv5we7woicjza7hc6s44yvy/db-password }}
```

**File**: `argocd/manifests/databases/blumeops-pg.yaml` (add to managed roles)
```yaml
managed:
  roles:
    # ... existing eblume role ...
    # borgmatic read-only user for backups
    - name: borgmatic
      login: true
      connectionLimit: -1
      ensure: present
      inherit: true
      inRoles:
        - pg_read_all_data
      passwordSecret:
        name: blumeops-pg-borgmatic
```

**Deploy**:
```bash
op inject -i argocd/manifests/databases/secret-borgmatic.yaml.tpl | kubectl apply -f -
argocd app set blumeops-pg --revision feature/p3-postgresql-borgmatic
argocd app sync blumeops-pg
```

---

### 7. Configure borgmatic for dual database backup

**File**: `ansible/roles/borgmatic/defaults/main.yml`
```yaml
borgmatic_postgresql_databases:
  # Brew PostgreSQL on indri (current production)
  - name: miniflux
    hostname: localhost
    port: 5432
    username: borgmatic
  # k8s PostgreSQL (CloudNativePG) - backup both during migration
  - name: miniflux
    hostname: k8s-pg.tail8d86e.ts.net
    port: 5432
    username: borgmatic
```

**File**: `ansible/roles/postgresql/tasks/main.yml` (update .pgpass)
```yaml
- name: Write .pgpass file for borgmatic backups
  ansible.builtin.copy:
    content: |
      # Managed by ansible - only read-only roles
      localhost:{{ postgresql_port }}:*:borgmatic:{{ postgresql_user_passwords['borgmatic'] }}
      k8s-pg.tail8d86e.ts.net:5432:*:borgmatic:{{ postgresql_user_passwords['borgmatic'] }}
    dest: ~/.pgpass
    mode: '0600'
  no_log: true
```

---

### 8. Verify complete backup pipeline

```bash
mise run provision-indri -- --tags borgmatic,postgresql
ssh indri '/opt/homebrew/bin/borgmatic --verbosity 1'
ssh indri 'borgmatic list --archive latest'
```

**Expected output**: Archive contains both dumps:
- `localhost/miniflux/miniflux`
- `k8s-pg.tail8d86e.ts.net/miniflux/miniflux`

---

### 9. Fix ArgoCD drift from CNPG defaults

**Problem**: ArgoCD showed blumeops-pg as OutOfSync due to CNPG operator adding default values.

**Solution**: Add CNPG defaults explicitly to managed roles.

**File**: `argocd/manifests/databases/blumeops-pg.yaml`
```yaml
managed:
  roles:
    - name: eblume
      # ... existing fields ...
      connectionLimit: -1
      ensure: present
      inherit: true
    - name: borgmatic
      # ... existing fields ...
      connectionLimit: -1
      ensure: present
      inherit: true
```

---

### 10. Update zk documentation

Updated:
- `~/code/personal/zk/borgmatic.md` - k8s-pg backup documentation and log entry
- `~/code/personal/zk/postgresql.md` - k8s PostgreSQL section and log entry

---

## New Files

| Path | Purpose |
|------|---------|
| `argocd/manifests/databases/secret-borgmatic.yaml.tpl` | borgmatic user password template |

## Modified Files

| Path | Change |
|------|--------|
| `ansible/roles/borgmatic/defaults/main.yml` | Added `borgmatic_local_path`, k8s-pg database entry |
| `ansible/roles/borgmatic/templates/config.yaml.j2` | Added `local_path` option |
| `ansible/roles/postgresql/tasks/main.yml` | Added k8s-pg to .pgpass |
| `argocd/apps/apps.yaml` | Disabled selfHeal |
| `argocd/manifests/databases/blumeops-pg.yaml` | Added borgmatic managed role, CNPG defaults |
| `pulumi/policy.hujson` | Added ACL grant homelab → k8s on tcp:5432 |

---

## Verification

- [x] borgmatic backup runs successfully
- [x] Miniflux data restored to k8s-pg (2 users, 2 feeds, 44 entries)
- [x] borgmatic user created in k8s-pg with pg_read_all_data role
- [x] Both localhost and k8s-pg databases in backup archive
- [x] ArgoCD shows blumeops-pg as Synced
- [x] zk documentation updated

---

## Rollback

Keep brew PostgreSQL running until Phase 4 verified. To revert:

1. Remove k8s-pg entry from borgmatic databases
2. Remove k8s-pg from .pgpass
3. `mise run provision-indri -- --tags borgmatic,postgresql`

---

## Implementation Notes

*Added during implementation for retrospective review*

### borgmatic LaunchAgent PATH Issue

**Problem**: borgmatic LaunchAgent failed with `borg: command not found`

**Root cause**: LaunchAgents run with minimal PATH that doesn't include `/opt/homebrew/bin`

**Solution**: Added `local_path: /opt/homebrew/bin/borg` to borgmatic config. This was already done for `pg_dump_command` but not for borg itself.

**Lesson**: Any tool invoked by borgmatic needs absolute path when running from LaunchAgent.

### 1Password Field Name Mismatch

**Issue**: Initial secret template used `password` field but 1Password item had `db-password`.

**Discovery**: Error message from `op inject` indicated field not found.

**Fix**: Updated template to use correct field name `db-password`.

### ACL Grant Discovery

**Problem**: Connection from indri (tag:homelab) to k8s-pg (tag:k8s) failed.

**Diagnosis**: Checked Tailscale operator proxy logs which showed "no rules matched" - clear indication of missing ACL.

**Solution**: Added explicit grant in `pulumi/policy.hujson` for `tag:homelab` → `tag:k8s` on `tcp:5432`.

### ArgoCD selfHeal and Feature Branch Development

**Problem**: When testing changes, temporarily pointed blumeops-pg app to feature branch via `argocd app set --revision`. ArgoCD's selfHeal kept reverting it back to main.

**Discussion**: Two options considered:
- Option A: Disable selfHeal on apps app (manual sync required for new apps)
- Option B: Keep selfHeal, use different workflow

**Decision**: Option A chosen. The apps app now only has `prune: true`, not selfHeal. This allows:
1. Temporarily testing feature branches
2. Manual control over when app manifest changes are applied

**Trade-off**: Must manually sync apps app when adding/removing Application manifests.

### CloudNativePG Managed Role Reconciliation

**Issue**: After creating borgmatic secret with correct password, CNPG didn't immediately update the user.

**Solution**: Annotated the Cluster to trigger reconciliation:
```bash
kubectl annotate cluster blumeops-pg -n databases cnpg.io/reconcile=$(date +%s) --overwrite
```

### ArgoCD Drift from CNPG Defaults

**Problem**: blumeops-pg showed OutOfSync despite successful syncs.

**Cause**: CNPG operator adds default values (`connectionLimit: -1`, `ensure: present`, `inherit: true`) to managed roles that weren't in our spec.

**Solution**: Added these defaults explicitly to our spec to match what CNPG generates.

**Comment added**: Documented in blumeops-pg.yaml that these are "CNPG defaults added to prevent ArgoCD drift".

### Git Workflow for Phase 3

1. Created feature branch: `feature/p3-postgresql-borgmatic`
2. Made commits throughout implementation
3. Pointed blumeops-pg app to feature branch for testing
4. Created PR #32 for review
5. After merge, reset app to main: `argocd app set blumeops-pg --revision main`

This workflow was enabled by disabling selfHeal (see above).
