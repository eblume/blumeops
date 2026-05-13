---
title: CNPG Operator on Ringtail
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - postgres
  - ringtail
---

# CNPG Operator on Ringtail

Bring up the `cloudnative-pg` operator on `k3s-ringtail`. Today the
operator only exists on `minikube-indri` (see
`argocd/apps/cloudnative-pg.yaml`, destination `kubernetes.default.svc`).

Prerequisite of [[migrate-immich-to-ringtail]]; consumed by
[[immich-pg-on-ringtail]].

## What to do

- Add a sibling `argocd/apps/cloudnative-pg-ringtail.yaml` pointing
  at the same mirror (`mirrors/cloudnative-pg`, tag `v1.27.1`),
  destination `https://ringtail.tail8d86e.ts.net:6443`,
  namespace `cnpg-system`.
- Mirror the `ServerSideApply=true` and `CreateNamespace=true` sync
  options (the CRDs exceed the annotation size limit).
- Sync `apps` then `cloudnative-pg-ringtail`. Verify the operator
  pod is running on ringtail.

## Verification

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

## Out of scope

- Postgres clusters themselves (`immich-pg`, etc.) — those come from
  [[immich-pg-on-ringtail]].
- Removing the minikube cnpg operator. That happens at the very end
  of the indri-k8s decommission, not in this chain.
