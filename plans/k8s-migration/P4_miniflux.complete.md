# Phase 4: Miniflux Migration to Kubernetes

**Goal**: Migrate Miniflux entirely off indri and onto k8s, retire brew PostgreSQL, rename k8s-pg to pg

**Status**: Complete (2026-01-20)

**Prerequisites**: [Phase 3](P3_postgresql.complete.md) complete

---

## Overview

This phase completed the miniflux migration and retired brew PostgreSQL:
1. Deployed miniflux container in k8s via ArgoCD
2. Exposed via Tailscale Ingress at `feed.tail8d86e.ts.net`
3. Removed all miniflux infrastructure from indri (ansible role, brew service, Tailscale serve)
4. Retired brew PostgreSQL (no longer needed)
5. Renamed k8s-pg to pg (canonical Tailscale hostname)
6. Updated borgmatic to backup only `pg.tail8d86e.ts.net`
7. Updated all zk documentation

---

## New Files

| Path | Purpose |
|------|---------|
| `argocd/apps/miniflux.yaml` | ArgoCD Application definition |
| `argocd/manifests/miniflux/deployment.yaml` | Miniflux Deployment |
| `argocd/manifests/miniflux/service.yaml` | ClusterIP Service |
| `argocd/manifests/miniflux/ingress-tailscale.yaml` | Tailscale Ingress for `feed.tail8d86e.ts.net` |
| `argocd/manifests/miniflux/secret-db.yaml.tpl` | Database URL secret documentation |
| `argocd/manifests/miniflux/kustomization.yaml` | Kustomize configuration |
| `argocd/manifests/miniflux/README.md` | Setup instructions |

## Modified Files

| Path | Change |
|------|--------|
| `ansible/playbooks/indri.yml` | Removed miniflux and postgresql roles, simplified pre_tasks |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Removed `svc:feed` and `svc:pg` entries |
| `ansible/roles/alloy/defaults/main.yml` | Removed miniflux and postgresql logs, disabled postgres metrics |
| `ansible/roles/borgmatic/defaults/main.yml` | Updated to backup only `pg.tail8d86e.ts.net` |
| `ansible/roles/borgmatic/tasks/main.yml` | Added .pgpass file management |
| `argocd/manifests/databases/service-tailscale.yaml` | Renamed hostname from k8s-pg to pg |

## Deleted Files

| Path | Reason |
|------|--------|
| `ansible/roles/miniflux/` | Entire role no longer needed |
| `ansible/roles/postgresql/` | Brew PostgreSQL no longer needed |

---

## Verification

- [x] Miniflux pod healthy in k8s
- [x] https://feed.tail8d86e.ts.net accessible
- [x] User `eblume` can log in
- [x] Feeds visible and entries readable
- [x] `pg.tail8d86e.ts.net` resolves to k8s PostgreSQL
- [x] Old `k8s-pg` and `feed` devices removed from Tailscale
- [x] brew miniflux and postgresql services stopped
- [x] Tailscale serve entries cleared from indri
- [x] zk documentation updated

---

## Implementation Notes

*Lessons learned and issues encountered*

### CNPG-Generated Password vs 1Password

**Problem**: Initial secret template used 1Password for miniflux database password, but CNPG auto-generates the bootstrap owner password.

**Solution**: Reference the CNPG-generated password from `blumeops-pg-app` secret:
```bash
kubectl create secret generic miniflux-db -n miniflux \
  --from-literal=url="$(kubectl -n databases get secret blumeops-pg-app -o jsonpath='{.data.uri}' | base64 -d)"
```

### Table Ownership Issue After P3 Restore

**Problem**: Miniflux pod crashed with "permission denied for table schema_version".

**Root cause**: P3 restore was run as the `eblume` superuser, so all tables were created owned by `eblume`, not `miniflux`.

**Solution**: Transfer ownership of all tables to miniflux:
```sql
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO miniflux';
    END LOOP;
END$$;
```

### Tailscale Ingress Hostname Suffix

**Behavior**: When requesting a Tailscale hostname that's already taken, the operator adds a suffix (e.g., `feed-1`).

**Workflow**:
1. Deploy initially - gets `feed-1.tail8d86e.ts.net`
2. Clear old `svc:feed` from indri
3. Delete old `feed` device from Tailscale admin
4. Delete and recreate the Ingress - now claims `feed`

### Renaming Tailscale Service Hostname

**Problem**: Changing the `tailscale.com/hostname` annotation doesn't automatically update the Tailscale device.

**Solution**: Delete the service and let ArgoCD recreate it:
```bash
kubectl -n databases delete service blumeops-pg-tailscale
argocd app sync blumeops-pg
```

### .pgpass Management Migration

**Issue**: The postgresql role managed `~/.pgpass` for borgmatic. With postgresql role deleted, borgmatic couldn't authenticate.

**Solution**: Moved .pgpass management to the borgmatic role. Password is still fetched in playbook pre_tasks as `borgmatic_db_password`.

### Ansible Check Mode and Registered Variables

**Problem**: Running `provision-indri --check --diff` failed in the podman role with "Conditional result (True) was derived from value of type 'str'" errors.

**Root cause**: Command tasks are skipped in check mode, leaving registered variables undefined or with unexpected types when used in conditionals.

**Solution**: Added `check_mode: false` to read-only command tasks that gather information:
```yaml
- name: Check if podman machine exists
  ansible.builtin.command:
    cmd: podman machine list --format json
  register: podman_machine_list
  changed_when: false
  check_mode: false  # Safe to run in check mode - read-only
```

**Lesson**: Any task that registers a variable used in conditionals should have `check_mode: false` if the command is read-only/safe.

### 1Password CLI on Headless Hosts

**Issue**: Attempted to run `op` commands on indri, but 1Password CLI requires interactive authentication (biometrics/password).

**Solution**: All `op` commands must be in `pre_tasks` of the playbook with `delegate_to: localhost` so they run on gilbert (the workstation with GUI auth).

### Git Workflow for Phase 4

1. Created feature branch: `feature/p4-miniflux`
2. Made incremental commits throughout implementation
3. Pointed `miniflux` and `blumeops-pg` apps to feature branch for testing
4. Created PR #33 for review
5. After merge, reset apps to main:
   ```bash
   argocd app set miniflux --revision main
   argocd app set blumeops-pg --revision main
   argocd app sync apps
   ```
