---
title: "Runbook: ArgoCD App Out of Sync"
modified: 2026-06-21
last-reviewed: 2026-06-21
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: ArgoCD App Out of Sync

**Alert name:** `ArgoCDAppOutOfSync`

An ArgoCD application has been out of sync for 5+ minutes (the alert's `for:` window). This means the live state in Kubernetes differs from what's declared in Git.

## Diagnostic Steps

1. **Check which app is out of sync** — the `name` label in the alert tells you:
   ```fish
   argocd app get <app-name>
   ```

2. **View the diff**:
   ```fish
   argocd app diff <app-name>
   ```

3. **Check if it's a branch revision issue** — during C1/C2 work, apps may be pointed at a feature branch. After merge, they need to be reset to main:
   ```fish
   argocd app get <app-name> -o json | python3 -c "import json,sys; print(json.load(sys.stdin)['spec']['source']['targetRevision'])"
   ```

4. **Check ArgoCD UI** — https://argocd.ops.eblu.me — look for sync errors or degraded status.

## Common Causes

- **Forgot to sync after push** — ArgoCD uses manual sync; changes require explicit `argocd app sync`
- **Branch revision not reset after PR merge** — app still points at a deleted branch
- **Kustomize/manifest error** — invalid YAML or unsatisfiable resource requirements
- **Pruning needed** — old ConfigMaps from `configMapGenerator` need pruning

## Resolution

```fish
# Simple sync
argocd app sync <app-name>

# If pruning is needed
argocd app sync <app-name> --prune

# If stuck on a deleted branch
argocd app set <app-name> --revision main
argocd app sync <app-name>
```

## Silencing

During active C1/C2 development, apps may intentionally be out of sync:
1. Grafana → Alerting → Silences → Create Silence
2. Match `alertname = ArgoCDAppOutOfSync` and `name = <app-name>`

## Related

- [[argocd]] — ArgoCD reference
- [[deploy-infra-alerting]] — Alerting pipeline overview
