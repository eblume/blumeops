---
title: Homepage
modified: 2026-10-08
last-reviewed: 2026-10-08
tags:
  - service
  - dashboard
---

# Homepage

Self-hosted dashboard of links and service widgets.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://go.ops.eblu.me |
| **Namespace** | `homepage` |
| **Image** | `registry.ops.eblu.me/blumeops/homepage` (nix-built, see `containers/homepage/default.nix`; current tag in `argocd/manifests/homepage/kustomization.yaml`) |
| **Upstream** | https://github.com/gethomepage/homepage |
| **Tracked upstream version** | `v1.13.2` (last v1 release; v2 migration pending) |
| **Config** | six YAML files in `argocd/manifests/homepage/` (`bookmarks`, `services`, `widgets`, `kubernetes`, `docker`, `settings`) folded into the `homepage-config` ConfigMap by `configMapGenerator` |

## Deployment

ArgoCD app `homepage` (auto-synced) deploys the nix-built image from
`registry.ops.eblu.me/blumeops/homepage`; the derivation builds the upstream
tag from the forge mirror `mirrors/homepage.git` (adapted from the nixpkgs
`homepage-dashboard` derivation — its Next.js cache-path `preBuild`
substitutions are load-bearing). Version bumps go through the
merge-triggered `build-container.yaml` workflow (no warrant, no dispatch):
merge the `containers/homepage/` bump, the push build tags the merge
commit, horkos opens the kustomization pin PR, and merging that pin is the
deploy.

## Related

- [[argocd]] - Deployment
- [[talos]] - Agent service surfaced on the dashboard
