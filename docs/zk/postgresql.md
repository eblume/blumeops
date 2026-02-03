---
id: postgresql
aliases:
  - postgresql
  - postgres
  - pg
tags:
  - blumeops
---

# PostgreSQL Management Log

PostgreSQL database cluster running in Kubernetes (minikube on indri) via CloudNativePG operator, providing storage for [[miniflux]] and other services.

## Quick Connect

```bash
# Connect as superuser (fetches password from 1Password)
PGPASSWORD=$(op --vault blumeops item get guxu3j7ajhjyey6xxl2ovsl2ui --fields password --reveal) psql -h pg.tail8d86e.ts.net -U eblume -d miniflux
```

## Service Details

- URL: tcp://pg.tail8d86e.ts.net:5432
- Metrics: http://cnpg-metrics.tail8d86e.ts.net:9187/metrics
- Namespace: databases
- Cluster name: blumeops-pg
- Operator: CloudNativePG
- ArgoCD app: blumeops-pg

## Databases

| Database | Owner    | Purpose                    |
|----------|----------|----------------------------|
| miniflux | miniflux | Miniflux feed reader data  |

## Users

| User      | Role             | Purpose                |
|-----------|------------------|------------------------|
| postgres  | superuser        | CNPG internal          |
| miniflux  | app owner        | Owns miniflux database |
| eblume    | superuser        | Admin access           |
| borgmatic | pg_read_all_data | Backup access          |

## Useful Commands

```bash
# List databases
PGPASSWORD=$(op --vault blumeops item get guxu3j7ajhjyey6xxl2ovsl2ui --fields password --reveal) psql -h pg.tail8d86e.ts.net -U eblume -c "\l"

# List users
PGPASSWORD=$(op --vault blumeops item get guxu3j7ajhjyey6xxl2ovsl2ui --fields password --reveal) psql -h pg.tail8d86e.ts.net -U eblume -c "\du"

# View CNPG cluster status
kubectl -n databases get cluster blumeops-pg

# View pod logs
kubectl -n databases logs -f blumeops-pg-1
```

## Backup

PostgreSQL data is backed up via borgmatic from indri using the `postgresql_databases` hook, which streams pg_dump directly to Borg for consistent backups.

Borgmatic config (`~/.config/borgmatic/config.yaml`):
```yaml
postgresql_databases:
    - name: miniflux
      hostname: pg.tail8d86e.ts.net
      port: 5432
      username: borgmatic
```

Password is read from `~/.pgpass` (managed by borgmatic ansible role).

## ArgoCD Management

```bash
# Sync cluster changes
argocd app sync blumeops-pg

# Force reconcile
kubectl annotate cluster blumeops-pg -n databases cnpg.io/reconcile=$(date +%s) --overwrite
```

**Files:**
- Cluster spec: `argocd/manifests/databases/blumeops-pg.yaml`
- Tailscale service: `argocd/manifests/databases/service-tailscale.yaml`
- Secrets: `secret-eblume.yaml.tpl`, `secret-borgmatic.yaml.tpl` (via `op inject`)

## Credentials

**1Password items:**
- `guxu3j7ajhjyey6xxl2ovsl2ui` - eblume superuser password
- `mw2bv5we7woicjza7hc6s44yvy` - borgmatic user password

**CNPG-managed secrets:**
- `blumeops-pg-app` - miniflux user (auto-generated password)
- `blumeops-pg-eblume` - eblume superuser
- `blumeops-pg-borgmatic` - borgmatic backup user

## Log

### Wed Jan 22 2026

- Added CNPG metrics collection via Tailscale service at `cnpg-metrics.tail8d86e.ts.net:9187`
- Updated PostgreSQL Grafana dashboard to use CNPG metric names (`cnpg_*` prefix)
- Prometheus on indri now scrapes CNPG metrics directly

### Sun Jan 19 2026 (P4)

- **Retired brew PostgreSQL** - k8s CloudNativePG is now the only PostgreSQL
- Renamed Tailscale hostname from `k8s-pg` to `pg` (canonical)
- Removed postgresql ansible role from indri
- Moved .pgpass management to borgmatic role
- Updated borgmatic to backup only `pg.tail8d86e.ts.net`
- Fixed table ownership issue: P3 restore created tables owned by eblume, transferred to miniflux

### Sun Jan 19 2026 (P3)

- Successfully tested disaster recovery: restored miniflux data from borgmatic backup to k8s-pg
- Added borgmatic user to k8s-pg via CloudNativePG managed roles
- Both brew and k8s PostgreSQL backed up by borgmatic during migration
- Added Tailscale ACL: `tag:homelab` → `tag:k8s` on port 5432 for backup access

### Thu Jan 16 2026

- Initial setup with PostgreSQL 18 (brew)
- Created miniflux database and user
- Exposed via Tailscale at pg.tail8d86e.ts.net
