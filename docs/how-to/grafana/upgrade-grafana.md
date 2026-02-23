---
title: Upgrade Grafana
status: active
requires:
  - kustomize-grafana-deployment
  - build-grafana-container
modified: 2026-02-23
tags:
  - how-to
  - grafana
  - observability
---

# Upgrade Grafana

Upgrade Grafana from 11.4.0 (Helm chart 8.8.2) to 12.x, converting from Helm to Kustomize with a home-built container image.

## Current State

| Property | Value |
|----------|-------|
| **Helm chart** | `grafana-8.8.2` (from forge mirror of `grafana/helm-charts`) |
| **Grafana app** | 11.4.0 |
| **Deployment** | Helm via ArgoCD multi-source |
| **Namespace** | `monitoring` |
| **Storage** | SQLite on 1Gi PVC |

Datasources: [[prometheus]], [[loki]], PostgreSQL (TeslaMate). Dashboard ConfigMaps provisioned via sidecar.

## Target State

- Grafana 12.x running from a home-built container (`forge.ops.eblu.me/eblume/grafana`)
- Kustomize manifests in `argocd/manifests/grafana/` (no Helm chart dependency)
- ArgoCD app simplified to a single source (kustomize directory)
- All existing datasources, dashboards, and Authentik OIDC intact

## Grafana 12 Breaking Changes

- **Angular plugin removal:** All AngularJS panels force-migrated to React. Our dashboards already use only React panels — no action needed.
- **Datasource UID format enforcement:** UIDs must be alphanumeric + dash/underscore, ≤40 chars. Our UIDs (`prometheus`, `loki`, `TeslaMate`) are compliant.
- **Annotation table migration:** Full rewrite of the `annotation` table (adds `dashboard_uid` column). Small SQLite DB — should be fast. PVC is disposable if anything goes wrong.

Overall risk: **Low.**

## Execution

Once both prerequisites are complete:

1. Update `argocd/apps/grafana.yaml` to point at the kustomize directory (single source, remove Helm multi-source)
2. Update `argocd/manifests/grafana/` with the kustomize manifests using the home-built image
3. Deploy on branch, verify with checklist below
4. Update `service-versions.yaml` to the new version and today's date

The SQLite PVC is disposable — dashboards are provisioned from ConfigMaps and datasources from config. No backup needed.

## Verification Checklist

- [ ] Pod running: `kubectl --context=minikube-indri -n monitoring get pods -l app.kubernetes.io/name=grafana`
- [ ] UI loads at `https://grafana.ops.eblu.me`
- [ ] Admin login works
- [ ] Authentik OIDC login works
- [ ] Datasources healthy: Prometheus, Loki, TeslaMate (Settings → Datasources → Test each)
- [ ] Key dashboards render: macOS System, Services Health, TeslaMate Overview
- [ ] Sidecar loaded all dashboard ConfigMaps
- [ ] `mise run services-check` passes
- [ ] No errors in pod logs

## Related

- [[grafana]] — Service reference card
- [[build-grafana-container]] — Prereq: build the container image
- [[kustomize-grafana-deployment]] — Prereq: create kustomize manifests
