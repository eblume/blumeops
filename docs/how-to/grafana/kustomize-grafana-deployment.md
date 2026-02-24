---
title: Kustomize Grafana Deployment
modified: 2026-02-23
tags:
  - how-to
  - grafana
---

# Kustomize Grafana Deployment

Grafana is deployed via plain Kustomize manifests in `argocd/manifests/grafana/`, replacing the previous Helm chart.

## Manifest Structure

| File | Purpose |
|------|---------|
| `kustomization.yaml` | Resource list |
| `deployment.yaml` | Grafana container + k8s-sidecar for dashboards |
| `service.yaml` | ClusterIP on port 80 → 3000 |
| `pvc.yaml` | 1Gi SQLite storage |
| `configmap.yaml` | `grafana.ini` and datasource provisioning |
| `serviceaccount.yaml` | Service account |
| `rbac.yaml` | ClusterRole/RoleBinding for sidecar ConfigMap access |

## Key Details

- **PVC name must remain `grafana`** — changing it would create a new volume and lose the SQLite DB
- **Sidecar** watches ConfigMaps with label `grafana_dashboard=1` and reloads dashboards via the Grafana API
- **Secrets** come from ExternalSecrets (`grafana-admin`, `grafana-authentik-oauth`, `grafana-teslamate-datasource`) managed by the `grafana-config` ArgoCD app

## Related

- [[upgrade-grafana]] — Migration context
- [[grafana]] — Service reference card
