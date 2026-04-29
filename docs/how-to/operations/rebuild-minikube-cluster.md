---
title: Rebuild Minikube Cluster (DR)
modified: 2026-04-13
last-reviewed: 2026-04-13
tags:
  - how-to
  - operations
  - disaster-recovery
---

# Rebuild Minikube Cluster (DR)

How to rebuild the minikube cluster from scratch after data loss (e.g., accidental `minikube delete`). This is a DR procedure — for normal restarts, see [[restart-indri]].

> **This procedure was validated during a real DR event on 2026-04-13** after a power loss and accidental `minikube delete` destroyed all cluster state.

## Prerequisites

- SSH access to indri (dismiss the macOS tailscaled permission dialog first — see [[restart-indri#0. Dismiss macOS Permission Dialogs]])
- Docker Desktop running on indri
- Tailscale connected
- 1Password CLI (`op`) authenticated

## Before You Start

### Clean Stale Tailscale Devices

Before bringing up the Tailscale operator, **delete stale service devices from the Tailscale admin console** (admin.tailscale.com). Old devices from the destroyed cluster will cause name collisions (new devices get `-1`, `-2` suffixes).

Look for offline tagged devices like: `pg`, `immich-pg`, `cnpg-metrics`, `ingress-0`, `ingress-1`, and any other `tag:k8s` devices that show "last seen" timestamps from before the rebuild.

If you miss this step, you'll need to: delete stale devices from the console, delete the Tailscale state secrets in k8s (`kubectl delete secret -n tailscale <name>`), and restart the affected pods.

> **Watch out for cross-cluster name collisions.** Both indri (minikube) and ringtail (k3s) use a ProxyGroup named `ingress`, producing pods named `ingress-0`, `ingress-1`. Deleting the wrong device can break the other cluster. Check which IPs are active before deleting. This is tech debt — the ProxyGroups should eventually be renamed to `indri-ingress` / `ringtail-ingress`.

## Phase 1: Start Minikube

```bash
minikube start --driver=docker --container-runtime=docker \
  --cpus=6 --memory=11264 --disk-size=200g \
  --apiserver-names=k8s.tail8d86e.ts.net --apiserver-names=indri \
  --apiserver-port=6443 --listen-address=0.0.0.0
```

Then run the ansible minikube role to configure Tailscale serve and registry mirrors:

```bash
mise run provision-indri -- --tags minikube
```

## Phase 2: Bootstrap Tailscale Operator

The Tailscale operator must be deployed before ArgoCD (ArgoCD uses Tailscale Ingress).

```bash
# 1. Create namespace
kubectl --context=minikube-indri create namespace tailscale

# 2. Create OAuth secret manually (ExternalSecrets isn't available yet)
CLIENT_ID=$(op read "op://blumeops/Tailscale K8s Operator OAuth/client-id")
CLIENT_SECRET=$(op read "op://blumeops/Tailscale K8s Operator OAuth/client-secret")
kubectl --context=minikube-indri create secret generic operator-oauth -n tailscale \
  --from-literal=client_id="$CLIENT_ID" \
  --from-literal=client_secret="$CLIENT_SECRET"

# 3. Apply operator manifests
#    NOTE: The kustomization fetches from forge.eblu.me which routes through
#    Fly → Tailscale → k8s (not yet up). Use forge.ops.eblu.me or github.com/eblume/blumeops.
#    Fetch the upstream manifest locally and build a temp kustomization:
curl -s "https://forge.ops.eblu.me/mirrors/tailscale/raw/tag/v1.94.2/cmd/k8s-operator/deploy/manifests/operator.yaml" \
  -o /tmp/ts-operator.yaml
# (create temp kustomization referencing local file — see memory/project_dr_lessons_2026_04.md for details)
kubectl --context=minikube-indri apply -k /tmp/ts-bootstrap/

# 4. Apply ProxyGroup for ingress
kubectl --context=minikube-indri apply -f argocd/manifests/tailscale-operator/proxygroup-ingress.yaml
```

## Phase 3: Bootstrap ArgoCD

```bash
# 1. Create namespace
kubectl --context=minikube-indri create namespace argocd

# 2. Apply ArgoCD (skip ExternalSecret resources — not available yet)
#    Create a temp kustomization without external-secret-*.yaml resources.
#    Use --server-side --force-conflicts for large CRDs (applicationsets).
kubectl --context=minikube-indri apply -k /tmp/argocd-bootstrap/ --server-side --force-conflicts

# 3. Wait for ArgoCD
kubectl --context=minikube-indri wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 4. Create forge SSH repo credentials
PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n'
KNOWN_HOSTS=$(ssh-keyscan -p 2222 forge.ops.eblu.me 2>/dev/null | grep ssh-rsa)
kubectl --context=minikube-indri create secret generic repo-creds-forge -n argocd \
  --from-literal=type=git \
  --from-literal=url='ssh://forgejo@forge.ops.eblu.me:2222/' \
  --from-literal=insecure=false \
  --from-literal=sshPrivateKey="$PRIV_KEY" \
  --from-literal=sshKnownHosts="$KNOWN_HOSTS"
kubectl --context=minikube-indri label secret repo-creds-forge -n argocd argocd.argoproj.io/secret-type=repo-creds

# 5. Apply app-of-apps
kubectl --context=minikube-indri apply -f argocd/apps/argocd.yaml
kubectl --context=minikube-indri apply -f argocd/apps/apps.yaml

# 6. Login and sync apps
argocd login argocd.tail8d86e.ts.net --username admin \
  --password "$(kubectl --context=minikube-indri -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" \
 argocd app sync apps```

## Phase 4: Bootstrap 1Password Connect + External Secrets

```bash
# 1. Sync foundation
argocd app sync external-secrets-crdsargocd app sync external-secretsargocd app sync 1password-connect
# 2. Create 1Password Connect secrets manually
CREDS_RAW=$(op read "op://blumeops/1Password Connect/credentials-file")
echo "$CREDS_RAW" | kubectl --context=minikube-indri create secret generic op-credentials -n 1password \
  --from-file=1password-credentials.json=/dev/stdin
TOKEN=$(op read "op://blumeops/1Password Connect/token")
kubectl --context=minikube-indri create secret generic onepassword-token -n 1password \
  --from-literal=token="$TOKEN"

# 3. Wait for 1Password Connect to start, then restart External Secrets
kubectl --context=minikube-indri wait --for=condition=available deployment/onepassword-connect -n 1password --timeout=120s
kubectl --context=minikube-indri rollout restart deployment -n external-secrets external-secrets

# 4. Verify ClusterSecretStore becomes Valid
kubectl --context=minikube-indri get clustersecretstores
```

## Phase 5: Sync Services (Dependency Order)

```bash
# Foundation (CRDs, operators)
argocd app sync cloudnative-pg kube-state-metrics
# Databases
argocd app sync blumeops-pg
# Observability
argocd app sync loki prometheus tempo grafana grafana-config
# Register ringtail cluster (for authentik, ntfy, ollama, frigate)
ssh ringtail 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
  sed 's|127.0.0.1|ringtail.tail8d86e.ts.net|' > /tmp/k3s-ringtail.yaml
KUBECONFIG=/tmp/k3s-ringtail.yaml argocd cluster add default --name k3s-ringtail --grpc-web -y

# Authentik (critical — Zot OIDC depends on it, most image pulls depend on Zot)
argocd app sync authentik
# Everything else
argocd app sync tailscale-operator alloy-k8s# ... remaining apps
```

## Phase 6: Restore Databases from Borgmatic

Databases come up empty. Restore from the latest borgmatic backup.

```bash
# Extract dumps
ssh indri 'mkdir -p /tmp/borg-restore && borgmatic extract --repository /Volumes/backups/borg --archive latest --destination /tmp/borg-restore --path borgmatic/postgresql_databases'

# Create databases that don't exist yet
kubectl --context=minikube-indri exec -n databases blumeops-pg-1 -c postgres -- \
  psql -U postgres -c "CREATE DATABASE teslamate OWNER teslamate;"
kubectl --context=minikube-indri exec -n databases blumeops-pg-1 -c postgres -- \
  psql -U postgres -c "CREATE DATABASE authentik OWNER authentik;"
# (repeat for other DBs as needed)

# For teslamate: create extensions BEFORE restoring
kubectl --context=minikube-indri exec -n databases blumeops-pg-1 -c postgres -- \
  psql -U postgres -d teslamate -c "CREATE EXTENSION IF NOT EXISTS cube CASCADE; CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;"

# For immich: create extensions BEFORE restoring
kubectl --context=minikube-indri exec -n databases immich-pg-1 -c postgres -- \
  psql -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS vchord CASCADE; CREATE EXTENSION IF NOT EXISTS cube CASCADE; CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE; CREATE EXTENSION IF NOT EXISTS pg_trgm; CREATE EXTENSION IF NOT EXISTS unaccent; CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

# Restore (dumps are in custom format — use pg_restore, not psql)
scp indri:/tmp/borg-restore/borgmatic/postgresql_databases/pg.ops.eblu.me:5432/miniflux /tmp/miniflux.sql
kubectl --context=minikube-indri exec -i -n databases blumeops-pg-1 -c postgres -- \
  pg_restore -U postgres -d miniflux --no-owner --role=miniflux < /tmp/miniflux.sql
# (repeat for teslamate, authentik, immich)

# Reset passwords to match current ExternalSecrets/CNPG-generated credentials
# The restored dumps contain OLD password hashes
PASS=$(kubectl --context=minikube-indri -n databases get secret blumeops-pg-app -o jsonpath='{.data.password}' | base64 -d)
kubectl --context=minikube-indri exec -n databases blumeops-pg-1 -c postgres -- \
  psql -U postgres -c "ALTER USER miniflux WITH PASSWORD '${PASS}';"
# (repeat for each user with the appropriate secret source)

# Create manually-managed DB secrets
kubectl --context=minikube-indri create secret generic miniflux-db -n miniflux \
  --from-literal=url="$(kubectl --context=minikube-indri -n databases get secret blumeops-pg-app -o jsonpath='{.data.uri}' | base64 -d)"
kubectl --context=minikube-indri create secret generic immich-db -n immich \
  --from-literal=password="$(kubectl --context=minikube-indri -n databases get secret immich-pg-app -o jsonpath='{.data.password}' | base64 -d)"
```

## Phase 7: Manual Fixups

### Forge Tailscale Ingress + Endpoints

The forge-external Endpoints must be applied manually (ArgoCD excludes Endpoints resources):

```bash
kubectl --context=minikube-indri apply -f argocd/manifests/tailscale-operator/svc-forge-external.yaml
kubectl --context=minikube-indri apply -f argocd/manifests/tailscale-operator/ingress-forge.yaml
kubectl --context=minikube-indri apply -f argocd/manifests/tailscale-operator/endpoints-forge.yaml
```

### Restart Fly.io Proxy

After the Tailscale ingress ProxyGroup gets new VIPs, the Fly.io proxy's MagicDNS cache may be stale:

```bash
FLY_API_TOKEN=$(op read "op://blumeops/fly.io admin/deploy-token") fly machine restart <machine-id> --app blumeops-proxy
```

### Grafana SQLite

If Grafana crashes with migration errors (`no such column: help_flags1`), delete its PVC and resync — Grafana is fully stateless (all config provisioned via ConfigMaps).

## Phase 8: Verify

```bash
mise run services-check
```

## Known Circular Dependencies

| Dependency | Breaks | Workaround |
|-----------|--------|------------|
| `forge.eblu.me` → Fly → Tailscale → k8s | tailscale-operator kustomization fetch | Fetch manifests from `forge.ops.eblu.me` or `github.com/eblume/blumeops` |
| Forgejo Actions secrets → Forgejo API → Caddy → k8s | Full ansible playbook | Use `--tags minikube` during bootstrap |
| Zot → Authentik OIDC | All container image pulls from Zot | Sync authentik early; Zot will crash-loop until OIDC is reachable |
| ArgoCD Endpoints exclusion → forge-external | Forge Tailscale ingress has no backend | Manual `kubectl apply` for Endpoints |

## Post-Rebuild: Cold Cache Failures

Devpi runs natively on indri (see [[devpi-on-indri]]) and is unaffected by minikube rebuilds, so the historical "devpi cold cache after rebuild" failure mode no longer applies. If devpi itself goes cold (fresh server-dir), the same lazy-cache race can still cause `404` on the first Dagger build under concurrent load — re-run the build to warm the cache, or pre-warm with `uv pip install --dry-run --index-url https://pypi.ops.eblu.me/root/pypi/+simple/ dagger-io`.

## Related

- [[restart-indri]] — Normal restart procedure (no data loss)
- [[disaster-recovery]] — DR overview
- [[borgmatic]] — Backup restoration
- [[cluster]] — Kubernetes cluster details
