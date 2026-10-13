---
title: "Runbook: ArgoCD App Out of Sync"
modified: 2026-10-13
last-reviewed: 2026-10-13
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: ArgoCD App Out of Sync

Two alerts share this runbook, split on the `autosync_enabled` label of the
`argocd_app_info` metric:

- **`ArgoCDAppOutOfSync`** (severity `warning`, `for: 5m`) — every app that
  is not explicitly manual (`autosync_enabled!="false"`), so an app missing
  the label (or any future value) fails toward alerting. OutOfSync after 5
  minutes is a real failure: a failed sync, a comparison error, or a hand
  edit. Treat it as an incident.
- **`ArgoCDManualAppPendingSync`** (severity `info`, `for: 24h`) — the four
  by-design manual apps (`apps`, `argocd`, `cloudnative-pg-ringtail`,
  `external-secrets-crds-ringtail`). OutOfSync here is not drift; it is a
  reviewed change waiting on a human sync. It fires only after a day, so it
  is a to-do, not an incident.

## Diagnostic Steps

1. **Check which app is out of sync** — the `name` label in the alert tells you:
   ```fish
   argocd app get <app-name>
   ```

2. **View the diff**:
   ```fish
   argocd app diff <app-name>
   ```

3. **Check if it's a branch revision issue** — during branch work, apps may be pointed at a feature branch. After merge, they need to be reset to main:
   ```fish
   argocd app get <app-name> -o json | python3 -c "import json,sys; print(json.load(sys.stdin)['spec']['source']['targetRevision'])"
   ```

4. **Check ArgoCD UI** — https://argocd.ops.eblu.me — look for sync errors or degraded status.

## Resolution

### `ArgoCDManualAppPendingSync` (manual app, pending human sync)

The diff is a reviewed merge that is simply not synced yet. Approve the
`argocd-sync-apps`/`argocd-deploy` warrant in Horkos, or sync it yourself
(`[human]` — the agent argocd CLI is read-only):

```fish
argocd app sync <app-name>
```

If the diff is *not* a reviewed change (unexpected, or older than a day
without an explanation), treat it as drift and diagnose below.

### `ArgoCDAppOutOfSync` (auto-sync app, real failure)

```fish
# Simple sync
argocd app sync <app-name>

# If pruning is needed
argocd app sync <app-name> --prune

# If stuck on a deleted branch
argocd app set <app-name> --revision main
argocd app sync <app-name>
```

## Common Causes (auto-sync apps)

- **Kustomize/manifest error** — invalid YAML or unsatisfiable resource requirements
- **Pruning needed** — old ConfigMaps from `configMapGenerator` need pruning
- **Branch revision not reset after PR merge** — app still points at a deleted branch
- **`apps` OutOfSync with a `syncPolicy.automated` field diff** — an Application manifest spells the defaults (`prune: false` / `selfHeal: false`); the controller strips explicit-false fields (Go `omitempty`) on every automated sync, so `apps` diffs forever. Fix the manifest to `automated: {}` (see [[argocd#Sync Policy]]); `argocd app diff apps` shows which app. Always record the diff *before* syncing `apps`.

## The `autosync_enabled` label

`autosync_enabled` is a native label on the `argocd_app_info` metric (ArgoCD
core metrics, scraped by the `argocd` Prometheus job), derived from each
Application's `spec.syncPolicy.automated`. Both rules partition on it.
Verified present on every series 2026-10-13 (`count by (name,
autosync_enabled) (argocd_app_info)` showed all apps labelled, the four
manual ones `false`).

## Silencing

During active branch development, apps may intentionally be out of sync:
1. Grafana → Alerting → Silences → Create Silence
2. Match `alertname` (`ArgoCDAppOutOfSync` or `ArgoCDManualAppPendingSync`) and `name = <app-name>`

## Related

- [[argocd]] — ArgoCD reference
- [[deploy-infra-alerting]] — Alerting pipeline overview
