---
title: Observability Stack
modified: 2026-04-06
last-reviewed: 2026-04-06
tags:
  - tutorials
  - replication
  - observability
---

# Building the Observability Stack

> **Audiences:** Replicator
>
> **Prerequisites:** [[kubernetes-bootstrap|Kubernetes Bootstrap]], [[argocd-config|ArgoCD Config]]

This tutorial walks through deploying metrics, logs, and dashboards for your homelab — because you can't fix what you can't see.

## The Stack

A complete observability solution has three pillars plus a collection layer:

| Component | Purpose | BlumeOps Uses |
|-----------|---------|---------------|
| **Metrics** | Numeric measurements over time | [[prometheus]] |
| **Logs** | Text output from applications | [[loki]] |
| **Dashboards** | Visualization and alerting | [[grafana]] |
| **Collection** | Gathering and forwarding data | [[alloy]] |

BlumeOps deploys all of these as plain kustomize manifests managed by ArgoCD — no Helm charts. See [[no-helm-policy]] for the rationale and [[observability]] for the full reference.

## Step 1: Create the Monitoring Namespace

ArgoCD can create this automatically via `CreateNamespace=true` in the Application spec, but if you're bootstrapping manually:

```bash
kubectl create namespace monitoring
```

## Step 2: Deploy Prometheus

Prometheus collects and stores metrics. BlumeOps runs it as a StatefulSet with local persistent storage.

### Write the Manifests

Create `argocd/manifests/prometheus/` with:

- **`kustomization.yaml`** — references the manifests and patches the container image
- **`statefulset.yaml`** — a single-replica StatefulSet with a 20Gi PVC for `/prometheus`
- **`configmap.yaml`** — the `prometheus.yml` scrape configuration
- **`service.yaml`** — exposes port 9090 within the cluster

Key StatefulSet settings:

```yaml
args:
  - "--config.file=/etc/prometheus/prometheus.yml"
  - "--storage.tsdb.retention.time=3650d"
  - "--web.enable-remote-write-receiver"
  - "--web.enable-lifecycle"
```

The remote-write-receiver flag is important — it lets [[alloy]] push metrics into Prometheus from both the host and in-cluster collectors.

### Tag the Image

Use your local container registry and the `:kustomized` sentinel pattern:

```yaml
# kustomization.yaml
images:
  - name: registry.ops.eblu.me/blumeops/prometheus
    newTag: v3.10.0-abcdef0
```

See [[build-container-image]] for how to build and tag images.

### Create the ArgoCD Application

Add `argocd/apps/prometheus.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git
    path: argocd/manifests/prometheus
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Verify

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=prometheus
```

## Step 3: Deploy Loki

Loki aggregates logs — think Prometheus, but for log lines instead of metrics.

### Write the Manifests

Create `argocd/manifests/loki/` with a StatefulSet, ConfigMap, and Service similar to Prometheus. Loki listens on port 3100 (HTTP) and 9096 (gRPC).

The config file (`loki-config.yaml`) defines storage, compaction, and retention. For a homelab, a simple single-binary mode with local filesystem storage works well — no need for S3 or distributed mode.

### Create the ArgoCD Application

Same pattern as Prometheus — point to `argocd/manifests/loki`, target `monitoring` namespace.

## Step 4: Deploy Grafana

Grafana provides dashboards, visualization, and alerting.

### Write the Manifests

Grafana has more moving parts than Prometheus or Loki:

- **Deployment** with a PVC for `/var/lib/grafana`
- **ConfigMap** containing `grafana.ini`, `datasources.yaml`, and `alerting.yaml`
- **Dashboard ConfigMaps** labeled `grafana_dashboard: "1"` — a sidecar container watches for these and auto-loads them
- **ExternalSecret** for the admin password (from 1Password via [[external-secrets]])

Configure data sources declaratively in the ConfigMap:

```yaml
# datasources.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus.monitoring.svc:9090
    isDefault: true
  - name: Loki
    type: loki
    url: http://loki.monitoring.svc:3100
```

### Secrets

Grafana's admin password and any OAuth credentials (for [[authentik]] SSO) should come from 1Password via ExternalSecret — never hardcode passwords in manifests. See [[external-secrets]] and [[security-model]].

### Expose via Caddy

BlumeOps exposes Grafana at `grafana.ops.eblu.me` through [[caddy]] on [[indri]], which reverse-proxies to the Kubernetes service via its Tailscale Ingress endpoint. This is the standard pattern for all services — see [[routing]] for details.

## Step 5: Deploy Alloy

Grafana Alloy is a unified telemetry collector that replaces multiple agents (Promtail, node_exporter, etc.). BlumeOps runs Alloy in **two places** — it is not optional; it's the glue that connects everything.

### In-Cluster (DaemonSet)

Create `argocd/manifests/alloy-k8s/` with:

- **DaemonSet** — runs on every node, mounts `/var/log` read-only for pod log access
- **ServiceAccount + RBAC** — needs pod list/watch for Kubernetes discovery
- **ConfigMap** — the `config.alloy` file defining:
  - Kubernetes pod log discovery and collection
  - Service health probes (blackbox-style checks for key services)
  - Remote write to Prometheus (`/api/v1/write`) and Loki (`/loki/api/v1/push`)

The DaemonSet goes in a dedicated `alloy` namespace, separate from `monitoring`.

### On the Host (Ansible)

For metrics and logs from native services (Forgejo, Zot, Caddy, Borgmatic), Alloy runs directly on [[indri]] as a macOS LaunchAgent, managed by [[ansible]].

The host Alloy collects:
- System metrics via `prometheus.exporter.unix`
- Logs from Homebrew services and LaunchAgents
- Optional: PostgreSQL metrics, container registry metrics

It pushes to the same Prometheus and Loki endpoints via `*.ops.eblu.me`.

## What You Now Have

- **Prometheus** scraping metrics from all services
- **Loki** aggregating logs from all pods and host services
- **Grafana** with declarative dashboards and data sources
- **Alloy** collecting from both Kubernetes and the host
- A foundation for alerting via Grafana Unified Alerting

## Adding Alerts

BlumeOps uses Grafana Unified Alerting (not Prometheus Alertmanager). Alerts are defined declaratively in `alerting.yaml` within the Grafana ConfigMap. Notifications go to [[ntfy]] — a self-hosted push notification service.

Example alert categories:
- Service probe failures (is Grafana/Prometheus/Loki reachable?)
- Pod readiness (are pods healthy?)
- Metrics freshness (is data still flowing?)
- Storage and resource thresholds

See [[observability]] for the full alerting reference.

## Adding Dashboards

Import community dashboards or create custom ones. BlumeOps uses a sidecar pattern — any ConfigMap in the `monitoring` namespace with the label `grafana_dashboard: "1"` is automatically loaded by Grafana's sidecar container.

Create dashboard ConfigMaps in `argocd/manifests/grafana-config/dashboards/`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-my-service
  labels:
    grafana_dashboard: "1"
data:
  my-service.json: |
    { ... dashboard JSON ... }
```

## Next Steps

- Set up [[authentik]] SSO for Grafana login (see [[federated-login]])
- Create custom dashboards for your services
- Configure alerting rules and notification channels
- Add service-specific metrics exporters

## Related

- [[observability]] — Full observability reference
- [[no-helm-policy]] — Why kustomize instead of Helm
- [[alloy]] — Alloy collector reference
- [[prometheus]] — Prometheus reference
- [[loki]] — Loki reference
- [[grafana]] — Grafana reference
- [[routing]] — Service routing and exposure
