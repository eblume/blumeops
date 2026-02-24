---
title: Upgrade Grafana
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

Upgraded Grafana from 11.4.0 (Helm chart) to 12.3.3, converting from Helm to Kustomize with a home-built container image.

## What Changed

- **Image:** `docker.io/grafana/grafana:11.4.0` → `registry.ops.eblu.me/blumeops/grafana:v12.3.3`
- **Deployment:** Helm multi-source (chart + values) → single Kustomize directory
- **ArgoCD app:** Simplified to one source pointing at `argocd/manifests/grafana/`

All existing datasources ([[prometheus]], [[loki]], TeslaMate), dashboard ConfigMaps, and Authentik OIDC were preserved without changes.

## Grafana 12 Breaking Changes

None affected us:

- **Angular plugin removal** — our dashboards already used React panels
- **Datasource UID format enforcement** — our UIDs were already compliant
- **Annotation table migration** — completed automatically on the small SQLite DB

## How to Repeat

To upgrade Grafana again in the future:

1. Update `CONTAINER_APP_VERSION` in `containers/grafana/Dockerfile`
2. Build and push via `mise run container-build-and-release grafana`
3. Update the image tag in `argocd/manifests/grafana/deployment.yaml`
4. Update `service-versions.yaml`
5. Sync: `argocd app sync grafana`

The SQLite PVC is disposable — dashboards come from ConfigMaps and datasources from config.

## Related

- [[grafana]] — Service reference card
- [[build-grafana-container]] — Building the container image
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
