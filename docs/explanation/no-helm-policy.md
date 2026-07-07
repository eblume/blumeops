---
title: No Helm Policy
modified: 2026-04-06
last-reviewed: 2026-07-07
tags:
  - explanation
  - kubernetes
---

# No Helm Policy

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

BlumeOps avoids Helm charts as a deployment mechanism. Plain kustomize manifests are the standard for all services.

## Rationale

Helm templates add a layer of abstraction that works against the simplicity of Kubernetes YAML manifests. Go templates embedded in YAML are hard to read, hard to diff, and hard to reason about. A manifest should be a manifest — not a program that generates one.

Kustomize overlays preserve the readability of plain YAML while providing the composition and patching features needed for environment-specific configuration. Version bumps are a one-line `newTag` edit in `kustomization.yaml`, and `kubectl diff` shows exactly what will change.

## Current State

All services in blumeops use kustomize manifests. The last Helm dependency (1Password Connect) was migrated in 2026-04.

## Migration History

Services previously deployed via Helm that have been migrated to kustomize:

| Service | Migrated | Notes |
|---------|----------|-------|
| Grafana | 2026-02 | Converted during v12.x upgrade |
| CloudNative-PG | 2026-02 | Switched to upstream release manifest via forge mirror |
| External Secrets | 2026-03 | Static manifests rendered from chart |
| Homepage | 2026-02 | Replaced chart with plain manifests |
| Immich | 2026-04 | Converted during v2.6.3 upgrade |
| 1Password Connect | 2026-04 | Rendered from chart v2.4.1, bumped to 1.8.2 |

## Guidelines

- **Do not introduce new Helm chart dependencies.** When deploying a new service, write kustomize manifests directly — even if the upstream project provides a Helm chart. The chart's `helm template` output is a fine starting point for writing those manifests.
- **When upgrading a Helm-based service**, consider whether it's a good time to migrate off Helm as part of the upgrade.
- **Upstream manifests** can be referenced directly in `kustomization.yaml` resources (like ArgoCD and Tailscale operator do) or applied via ArgoCD's `directory.include` (like CloudNative-PG). Both avoid Helm.

## Related

- [[review-services]] — Service review process
- [[architecture]] — Overall infrastructure design
