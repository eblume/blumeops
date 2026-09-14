---
title: Upgrade Grafana
modified: 2026-03-04
last-reviewed: 2026-03-04
tags:
  - how-to
  - grafana
  - observability
---

# Upgrade Grafana

Upgraded Grafana from 11.4.0 (Helm chart) to 12.3.3, converting from Helm to Kustomize with a home-built container image.

## What Changed

- **Image:** `docker.io/grafana/grafana:11.4.0` → `registry.ops.eblu.me/blumeops/grafana` (tagged via Kustomize `images:` overlay)
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

1. Update `version = "..."` in `containers/grafana/default.nix` (see [[build-grafana-images]]) and `service-versions.yaml` in the same PR
2. Merge — the push to main builds at the merge commit and pushes the image to the registry (tag SHA = the merge commit)
3. Merge the kustomization pin PR the horkos publisher opens with the new tag in `argocd/manifests/grafana-ringtail/kustomization.yaml` (under `images:`) — merging it deploys

The SQLite PVC is disposable — dashboards come from ConfigMaps and datasources from config.

## Related

- [[grafana]] — Service reference card
- [[build-grafana-images]] — Building the container images
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
