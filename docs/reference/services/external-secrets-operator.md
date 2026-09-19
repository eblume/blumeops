---
title: External Secrets Operator
modified: 2026-09-19
last-reviewed: 2026-09-19
tags:
  - service
  - secrets
---

# External Secrets Operator

Operator that syncs secrets from 1Password (via Connect) into Kubernetes Secrets. Runs in the `external-secrets` namespace on ringtail's k3s cluster.

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `external-secrets` |
| **Image** | `registry.ops.eblu.me/blumeops/external-secrets` (tag pinned in `argocd/manifests/external-secrets-ringtail/kustomization.yaml`) |
| **Operator app** | `external-secrets-ringtail` (auto-sync) |
| **CRDs app** | `external-secrets-crds-ringtail` (manual sync, CRDs first) |

## Deployment context

- **Image**: built in blumeops — `containers/external-secrets/default.nix` compiles the forge mirror (`mirrors/external-secrets`) with the `all_providers` build tag. A merge to main touching `containers/**` builds and pushes the image; horkos opens the kustomization pin PR for the new tag.
- **Manifests**: static kustomize rendered from the upstream Helm chart, in `argocd/manifests/external-secrets/` (base, kept in lockstep with the indri line) with the `external-secrets-ringtail` overlay.
- **CRDs**: from `config/crds/bases` at the mirror's `helm-chart-X.Y.Z` tag, via the deliberately manual `external-secrets-crds-ringtail` app. It must sync **before** the operator app so the CRD schema leads the operator binary; the two are deployed as a matched pair.
- **Consumers**: services define `ExternalSecret` objects against the 1Password Connect `ClusterSecretStore`.

## Related

- [[1password]] - Credential management (Connect server under `argocd/manifests/1password-connect/`)
- [[external-secrets|External Secrets]] - usage notes in `docs/reference/kubernetes/`
