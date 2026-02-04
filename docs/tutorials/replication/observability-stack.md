---
title: observability-stack
tags:
  - tutorials
  - replication
  - observability
---

# Building the Observability Stack

> **Audiences:** Replicator

This tutorial walks through deploying metrics, logs, and dashboards for your homelab - because you can't fix what you can't see.

## The Stack

A complete observability solution has three pillars:

| Component | Purpose | BlumeOps Uses |
|-----------|---------|---------------|
| **Metrics** | Numeric measurements over time | [[prometheus]] |
| **Logs** | Text output from applications | [[loki]] |
| **Dashboards** | Visualization and alerting | [[grafana]] |
| **Collection** | Gathering and forwarding data | [[alloy]] |

For BlumeOps specifics, see [[observability|Observability Reference]].

## Step 1: Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

## Step 2: Deploy Prometheus

Prometheus collects and stores metrics.

### Using Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set server.persistentVolume.size=10Gi
```

### Or via ArgoCD

Create an Application pointing to a values file in your repo:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: prometheus
    targetRevision: 25.0.0
    helm:
      values: |
        server:
          persistentVolume:
            size: 10Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
```

### Verify

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=prometheus
```

## Step 3: Deploy Loki

Loki aggregates logs (like Prometheus but for logs).

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

This also installs Promtail for log collection from pods.

## Step 4: Deploy Grafana

Grafana provides dashboards and visualization.

```bash
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=true \
  --set persistence.size=1Gi \
  --set adminPassword=admin  # Change this!
```

### Configure Data Sources

After installation, add data sources in Grafana UI or via ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring.svc:80
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki.monitoring.svc:3100
```

## Step 5: Access Grafana

Expose via Tailscale:
```bash
kubectl -n monitoring port-forward svc/grafana 3000:80 &
tailscale serve --bg --https 3000 http://localhost:3000
```

Or create an Ingress.

Default credentials: `admin` / (password you set or retrieve from secret)

## Step 6: Add Dashboards

Import community dashboards from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards/):

| Dashboard | ID | Shows |
|-----------|-----|-------|
| Node Exporter Full | 1860 | Host metrics |
| Kubernetes Cluster | 7249 | Cluster overview |
| Loki Logs | 13639 | Log exploration |

In Grafana: Dashboards > Import > Enter ID

## Step 7: Deploy Alloy (Optional)

Grafana Alloy is a unified collector that replaces multiple agents (Promtail, node_exporter, etc.).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: alloy
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: alloy
    targetRevision: 0.1.0
    helm:
      values: |
        alloy:
          configMap:
            content: |
              // Alloy configuration here
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
```

BluemeOps uses Alloy on both [[indri]] (for host metrics, via [[reference/ansible/roles | Ansible role]]) and in the [[cluster]] (for pod logs and service probes).

## What You Now Have

- Metrics collection and storage (Prometheus)
- Log aggregation (Loki)
- Dashboards and visualization (Grafana)
- Foundation for alerting

## Adding Alerts

Configure alerting rules in Prometheus:

```yaml
groups:
- name: example
  rules:
  - alert: HighMemoryUsage
    expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage detected"
```

And notification channels in Grafana (email, Slack, PagerDuty, etc.).

## Next Steps

- Create custom dashboards for your services
- Set up alerting for critical conditions
- Add service-specific metrics exporters

## BluemeOps Specifics

BlumeOps' observability setup includes:
- Prometheus scraping all services via annotations
- Loki collecting logs from all pods and [[indri]] services
- Custom dashboards for [[jellyfin]], [[teslamate]], and cluster health
- [[alloy]] running on both host and in-cluster

See [[observability|Observability Reference]] for full details.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No metrics appearing | Check Prometheus targets (`/targets` endpoint) |
| No logs in Loki | Verify Promtail/Alloy is collecting (`/ready` endpoint) |
| Dashboard shows no data | Check data source configuration and time range |
| High storage usage | Adjust retention settings in Prometheus/Loki |
