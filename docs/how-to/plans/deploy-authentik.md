---
title: "Plan: Deploy Authentik Identity Provider"
modified: 2026-02-20
tags:
  - how-to
  - plans
  - authentik
  - security
  - oidc
---

# Plan: Deploy Authentik Identity Provider

> **Status:** Planned (not yet executed)
> **Phases:** 6 (execute sequentially, each as a separate PR where practical)

## Background

[[dex]] is a lightweight OIDC broker but doesn't manage users or provision accounts — it delegates everything to [[forgejo]] as the upstream identity source. This works for single-user SSO but limits future capabilities: no central user/group management, no SAML or LDAP support, no JIT provisioning, no self-service flows.

Authentik is a full identity provider that provides:

- **Central user/group management** — accounts, permissions, recovery flows
- **Multi-protocol support** — OIDC, SAML, LDAP, SCIM, proxy auth
- **JIT provisioning** — automatically create downstream accounts on first login
- **Self-service** — password reset, profile management, enrollment flows
- **Admin UI** — web-based management console

Authentik will eventually replace Dex and become the SSO source of truth for all BlumeOps services. Forgejo remains the upstream identity source via OAuth2 connector (same as today with Dex), but Authentik adds the management layer Dex lacks.

### Current State

| Property | Value |
|----------|-------|
| **Current IdP** | Dex (on [[ringtail]] k3s) |
| **Identity source** | Forgejo OAuth2 |
| **OIDC clients** | [[grafana]] |
| **Dex container** | Nix-built `blumeops/dex` |
| **Dex manifests** | `argocd/manifests/dex/` |

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Cluster** | ringtail (k3s) | IdP independent of main services cluster, same as Dex |
| **Database** | Existing CNPG `blumeops-pg` on indri (cross-cluster via Tailscale) | No new database operator needed, proven pattern |
| **Redis** | Co-deployed in authentik namespace | Required for caching/sessions/task queue; split out later if shared |
| **Containers** | Nix-built (`dockerTools.buildLayeredImage`) | Supply chain control, consistent with Dex/ntfy pattern |
| **Manifests** | Kustomize (no Helm) | Consistent with all other BlumeOps services |
| **Networking** | Tailscale Ingress + Caddy reverse proxy | Same pattern as Dex |

---

## Phase 0: Helm Template Analysis

**Goal:** Understand what Kubernetes resources Authentik needs by templating the upstream Helm chart, then discard it.

1. Add the Authentik Helm repo:
   ```fish
   helm repo add authentik https://charts.goauthentik.io
   helm repo update
   ```
2. Template with external database/redis (we provide our own):
   ```fish
   helm template authentik authentik/authentik \
     --set postgresql.enabled=false \
     --set redis.enabled=false > /tmp/authentik-helm-output.yaml
   ```
3. Review output — extract resource types, env vars, ports, probes, volumes
4. Use findings to inform the kustomize manifests in Phase 3

### Files Modified

None — analysis only.

---

## Phase 1: Prerequisites

### 1a. Mirror Upstream Repos

Mirror for supply chain control/audit:

| Upstream | Forge Mirror |
|----------|-------------|
| `https://github.com/goauthentik/authentik` | `forge.ops.eblu.me/eblume/authentik` |
| `https://github.com/redis/redis` | `forge.ops.eblu.me/eblume/redis` (if needed for reference) |

User creates the mirrors via Forgejo UI; confirm they exist before proceeding.

### 1b. Check nixpkgs for Authentik Package

- Check if `pkgs.authentik` exists in nixpkgs (there is a `services.authentik` NixOS module, suggesting the package exists)
- If available: use it in `dockerTools.buildLayeredImage` (same pattern as `containers/dex/default.nix`)
- If NOT available: write a Nix derivation to package Authentik from source

### 1c. Add Authentik Database to blumeops-pg

The existing CNPG cluster on indri (`argocd/manifests/databases/blumeops-pg.yaml`) already hosts miniflux, teslamate, borgmatic, and eblume roles. Add an authentik role following the same pattern.

**Modify** `argocd/manifests/databases/blumeops-pg.yaml` — add managed role:
```yaml
# authentik user for Authentik identity provider
- name: authentik
  login: true
  connectionLimit: -1
  ensure: present
  inherit: true
  createdb: true
  passwordSecret:
    name: blumeops-pg-authentik
```

**Create** `argocd/manifests/databases/external-secret-authentik.yaml` — ExternalSecret pulling authentik DB password from 1Password (follow `external-secret-teslamate.yaml` pattern).

**Modify** `argocd/manifests/databases/kustomization.yaml` — add `external-secret-authentik.yaml` to resources.

### 1d. 1Password Secrets

Create item **"Authentik (blumeops)"** in vault `blumeops` with fields:

| Field | Purpose |
|-------|---------|
| `db-password` | PostgreSQL password for authentik role |
| `secret-key` | Authentik internal secret key (crypto operations) |
| `bootstrap-password` | Initial admin password |

### Files Modified

| Action | File |
|--------|------|
| Modify | `argocd/manifests/databases/blumeops-pg.yaml` |
| Create | `argocd/manifests/databases/external-secret-authentik.yaml` |
| Modify | `argocd/manifests/databases/kustomization.yaml` |

---

## Phase 2: Nix Containers

### Authentik Container

**Create** `containers/authentik/default.nix`:

- Use `pkgs.authentik` (or build from source if not in nixpkgs)
- Include: authentik, cacert, tzdata, bash (for migrations/management commands)
- Entrypoint: authentik server binary
- Cmd: configurable (server vs worker via args)
- Ports: 8000 (HTTP), 8443 (HTTPS), 9300 (metrics)
- Follow the pattern established in `containers/dex/default.nix`

### Redis Container

**Create** `containers/redis/default.nix`:

```nix
{ pkgs ? import <nixpkgs> { } }:
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/redis";
  tag = "latest";
  contents = [ pkgs.redis ];
  config = {
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    ExposedPorts = { "6379/tcp" = { }; };
    User = "65534";
  };
}
```

### Build & Release

```fish
nix-build containers/authentik/default.nix
mise run container-tag-and-release authentik v1.0.0

nix-build containers/redis/default.nix
mise run container-tag-and-release redis v1.0.0
```

Forgejo workflow builds and pushes to `registry.ops.eblu.me/blumeops/authentik:v1.0.0-nix` and `registry.ops.eblu.me/blumeops/redis:v1.0.0-nix`.

### Files Modified

| Action | File |
|--------|------|
| Create | `containers/authentik/default.nix` |
| Create | `containers/redis/default.nix` |

---

## Phase 3: Kustomize Manifests & ArgoCD App

### Manifest Directory

**Create** `argocd/manifests/authentik/` with the following resources:

```
argocd/manifests/authentik/
├── kustomization.yaml
├── deployment-server.yaml
├── deployment-worker.yaml
├── deployment-redis.yaml
├── service-server.yaml
├── service-redis.yaml
├── ingress-tailscale.yaml
└── external-secret.yaml
```

### deployment-server.yaml

- Image: `registry.ops.eblu.me/blumeops/authentik:v1.0.0-nix`
- Args: `server`
- Ports: 8000 (HTTP), 8443 (HTTPS), 9300 (metrics)
- Env from ExternalSecret: `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__*`, `AUTHENTIK_REDIS__HOST`, `AUTHENTIK_BOOTSTRAP_PASSWORD`
- PostgreSQL host: Tailscale DNS for blumeops-pg on indri (via `service-tailscale.yaml` in databases namespace)
- Redis host: `redis.authentik.svc.cluster.local`
- Liveness probe: `/-/health/live/`
- Readiness probe: `/-/health/ready/`

### deployment-worker.yaml

- Same image, args: `worker`
- Same env vars
- Port: 9300 (metrics only)
- Liveness probe: `/-/health/live/`

### deployment-redis.yaml

- Image: `registry.ops.eblu.me/blumeops/redis:v1.0.0-nix`
- Port: 6379
- Liveness probe: TCP check on 6379
- PVC: 1Gi for persistence

### service-server.yaml

- Ports: 80→8000, 443→8443, 9300→9300

### service-redis.yaml

- Port: 6379→6379 (ClusterIP, internal only)

### ingress-tailscale.yaml

- IngressClass: `tailscale`
- Annotations: `proxy-group: ingress`, gethomepage widget annotations
- Backend: authentik server service, port 8000
- TLS host: `authentik`

### external-secret.yaml

- Pull from 1Password item "Authentik (blumeops)"
- Template into a Secret with keys for `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__*`, `AUTHENTIK_REDIS__HOST`, `AUTHENTIK_BOOTSTRAP_PASSWORD`
- Include DB connection components (host, port, user, password, name)

### ArgoCD Application

**Create** `argocd/apps/authentik.yaml` following the Dex app pattern:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentik
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/authentik
  destination:
    server: https://ringtail.tail8d86e.ts.net:6443
    namespace: authentik
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Files Modified

| Action | File |
|--------|------|
| Create | `argocd/apps/authentik.yaml` |
| Create | `argocd/manifests/authentik/kustomization.yaml` |
| Create | `argocd/manifests/authentik/deployment-server.yaml` |
| Create | `argocd/manifests/authentik/deployment-worker.yaml` |
| Create | `argocd/manifests/authentik/deployment-redis.yaml` |
| Create | `argocd/manifests/authentik/service-server.yaml` |
| Create | `argocd/manifests/authentik/service-redis.yaml` |
| Create | `argocd/manifests/authentik/ingress-tailscale.yaml` |
| Create | `argocd/manifests/authentik/external-secret.yaml` |

---

## Phase 4: Networking

### Caddy Routing

**Modify** `ansible/roles/caddy/defaults/main.yml` — add authentik to `caddy_services`:
```yaml
- name: authentik
  host: authentik
  backend: "https://authentik.tail8d86e.ts.net"
```

This makes Authentik available at `https://authentik.ops.eblu.me`.

### Deployment

```fish
mise run provision-indri -- --tags caddy --check --diff  # dry run
mise run provision-indri -- --tags caddy                  # after approval
```

### Files Modified

| Action | File |
|--------|------|
| Modify | `ansible/roles/caddy/defaults/main.yml` |

---

## Phase 5: Monitoring

### Prometheus Metrics

Authentik exposes Prometheus metrics on port 9300 at `/metrics` (both server and worker). Options for scraping from Prometheus on indri:

1. **ServiceMonitor** (if Prometheus operator CRDs exist on ringtail) — preferred but may require setup
2. **Prometheus scrape annotation** on the service — simpler but requires Prometheus to reach ringtail pods
3. **Tailscale service for metrics** — expose authentik metrics endpoint via Tailscale, scrape from indri

The cross-cluster scraping pattern needs investigation — Dex currently does not have metrics collection, so this is new territory.

### Log Collection

Ringtail may not have pod log collection to Loki yet. At minimum:

- Document how to view logs: `kubectl --context=k3s-ringtail -n authentik logs deploy/authentik-server`
- Stretch: deploy alloy-k8s to ringtail for pod log collection → Loki on indri

### Grafana Dashboard

If relevant Authentik dashboards exist upstream, add as a ConfigMap in `argocd/manifests/grafana-config/dashboards/`.

### Files Modified

Depends on approach chosen during execution.

---

## Phase 6: Documentation & PR

### Changelog

Create `docs/changelog.d/<branch>.feature.md` with summary of Authentik deployment.

### Documentation Updates

| Action | File | Change |
|--------|------|--------|
| Create | `docs/reference/services/authentik.md` | Service reference card |
| Modify | `docs/reference/services/services.md` | Add authentik to service index |
| Modify | `docs/explanation/federated-login.md` | Reflect Authentik replacing Dex |
| Modify | `docs/how-to/plans/plans.md` | Update plan status |

---

## Verification Checklist

- [ ] Container builds succeed: `nix-build containers/authentik/default.nix` and `nix-build containers/redis/default.nix`
- [ ] Database role exists: `kubectl --context=minikube-indri -n databases exec -it blumeops-pg-1 -- psql -U postgres -c "\du"` shows authentik role
- [ ] Pods running: `kubectl --context=k3s-ringtail -n authentik get pods` shows server, worker, redis all Running
- [ ] Health check: `curl -k https://authentik.tail8d86e.ts.net/-/health/live/` returns 200
- [ ] Web UI: `https://authentik.ops.eblu.me` loads the Authentik login page
- [ ] Admin login: bootstrap credentials work for initial admin access
- [ ] Metrics: Prometheus can scrape authentik metrics (port 9300)
- [ ] Services check: `mise run services-check` passes (after adding authentik)

## Open Questions

1. **Authentik in nixpkgs:** Need to verify `pkgs.authentik` exists and works for container builds. If not, packaging from source in Nix is a significant sub-task.
2. **Cross-cluster DB latency:** Authentik on ringtail → PostgreSQL on indri via Tailscale should be fine for a homelab but worth monitoring after deployment.
3. **Redis persistence:** Using a PVC for Redis data. Authentik handles Redis loss gracefully (sessions regenerate), so this is low-risk.
4. **Metrics scraping cross-cluster:** Prometheus on indri scraping authentik metrics on ringtail may need a dedicated Tailscale service or a push-based approach. Dex doesn't currently have metrics collection, so this is a new pattern to establish.
5. **Dex decommission timing:** When to remove Dex? After all OIDC clients are migrated to Authentik and verified working. This is a separate plan.

## Key Files

| File | Purpose |
|------|---------|
| `containers/authentik/default.nix` | Nix container build (new) |
| `containers/redis/default.nix` | Redis Nix container (new) |
| `containers/dex/default.nix` | Existing Dex container (pattern reference) |
| `argocd/apps/authentik.yaml` | ArgoCD Application (new) |
| `argocd/apps/dex.yaml` | Existing Dex app (pattern reference) |
| `argocd/manifests/authentik/` | Kustomize manifests (new) |
| `argocd/manifests/dex/` | Existing Dex manifests (pattern reference) |
| `argocd/manifests/databases/blumeops-pg.yaml` | CNPG cluster (add authentik role) |
| `ansible/roles/caddy/defaults/main.yml` | Caddy reverse proxy config |

## Related

- [[dex]] — Current IdP (to be replaced)
- [[federated-login]] — How authentication works across BlumeOps
- [[adopt-oidc-provider]] — Dex deployment plan (completed)
- [[cluster]] — Kubernetes infrastructure
- [[ringtail]] — Target cluster for Authentik
- [[apps]] — ArgoCD application inventory
