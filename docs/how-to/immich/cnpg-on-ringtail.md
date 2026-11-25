---
title: CNPG Operator on Ringtail
modified: 2026-11-25
last-reviewed: 2026-11-25
tags:
  - how-to
  - operations
  - postgres
  - ringtail
---

# CNPG Operator on Ringtail

The `cloudnative-pg` operator runs on `k3s-ringtail` in `cnpg-system`,
deployed by the ArgoCD app `cloudnative-pg-ringtail`. The minikube
operator was removed with the indri-k8s decommission, so ringtail is the
only cluster with the operator.

PostgreSQL clusters are not part of this app; they come from
[[immich-pg-on-ringtail]]. This operator is the prerequisite of
[[migrate-immich-to-ringtail]].

## How it is deployed

- `argocd/apps/cloudnative-pg-ringtail.yaml` tracks the
  `mirrors/cloudnative-pg` release manifest at tag `v1.30.1`
  (`releases/cnpg-1.30.1.yaml`), destination the cluster ArgoCD runs on,
  namespace `cnpg-system`.
- `ServerSideApply=true` and `CreateNamespace=true` are set (the CRDs
  exceed the annotation size limit).
- Sync is **manual**, by design: the app tracks a mutable mirror tag, so
  a re-mirrored tag would otherwise deploy with no review. See
  [[argocd]] for the sync-policy reasoning.

## Upgrading the operator

1. Merge a PR that bumps `targetRevision` (and the `include` filename)
   in `argocd/apps/cloudnative-pg-ringtail.yaml`.
2. Run `argocd-sync-apps.yaml` so the root syncs the Application spec.
3. Run `argocd-deploy.yaml` with `-i revision=declared` to sync the app
   at its declared tag.

An operator upgrade rolls the instance pods to pick up the new instance
manager, so expect a brief restart of the single-instance clusters.

## Verification

```bash
argocd app get cloudnative-pg-ringtail
```

Expect `Synced` and `Healthy`, the `cnpg-controller-manager` Deployment
healthy, and `clusters.postgresql.cnpg.io` among the CRDs.

From a host with `kubectl`:

```fish
kubectl --context=k3s-ringtail -n cnpg-system get pods
kubectl --context=k3s-ringtail get crd clusters.postgresql.cnpg.io
```

## Why a separate app

Each ArgoCD app targets a single cluster via `destination.server`.
We could parameterize with ApplicationSets, but blumeops' convention
is to duplicate the manifest with a `-ringtail` suffix (see
`alloy-ringtail`, `external-secrets-ringtail`, etc.). Keep the
convention.
