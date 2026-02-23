---
title: Kustomize Grafana Deployment
status: active
modified: 2026-02-23
tags:
  - how-to
  - grafana
---

# Kustomize Grafana Deployment

Convert Grafana from a Helm chart deployment to plain Kustomize manifests.

## Context

Grafana is currently deployed via ArgoCD using a Helm chart (`grafana-8.8.2`) from a forge mirror. The chart produces: Deployment, Service, PVC, ConfigMaps (grafana.ini, datasources), RBAC resources, and a sidecar container for dashboard provisioning.

## Steps

1. Template the current Helm chart to see what it produces:
   ```fish
   # From the forge mirror, or use argocd app manifests
   argocd app manifests grafana > /tmp/grafana-helm-output.yaml
   ```
2. Create Kustomize equivalents in `argocd/manifests/grafana/`:
   - `kustomization.yaml`
   - `deployment.yaml` — Grafana container + k8s-sidecar container
   - `service.yaml`
   - `pvc.yaml` — Reuse existing 1Gi PVC
   - `configmap.yaml` — grafana.ini and datasource provisioning
   - `rbac.yaml` — ClusterRole, ClusterRoleBinding, Role, RoleBinding
3. Update `argocd/apps/grafana.yaml` to use a single kustomize source instead of the Helm multi-source
4. Remove the Helm values.yaml (replaced by the kustomize manifests)

## Notes

- The existing PVC must not be deleted during the transition — ensure the kustomize PVC matches the existing one's name
- The sidecar (`quay.io/kiwigrid/k8s-sidecar`) should also be replaced with a home-built image eventually, but is lower priority — focus on Grafana itself first
- Preserve all existing config: Authentik OIDC, datasources, dashboard sidecar labels

## Related

- [[upgrade-grafana]] — Goal card
