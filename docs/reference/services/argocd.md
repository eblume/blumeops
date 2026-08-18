---
title: ArgoCD
modified: 2026-08-18
last-reviewed: 2026-06-09
tags:
  - service
  - gitops
---

# ArgoCD

GitOps continuous delivery platform for the [[cluster|Kubernetes cluster]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://argocd.ops.eblu.me |
| **Tailscale URL** | https://argocd.tail8d86e.ts.net |
| **Namespace** | `argocd` |
| **Git Source** | `ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git` |
| **Manifests Path** | `argocd/apps/` (Applications), `argocd/manifests/` (workloads) |

## Clusters

One ArgoCD instance on [[ringtail]]'s k3s, managing that cluster in-place — every Application targets `https://kubernetes.default.svc`. The indri minikube cluster it used to also manage was decommissioned; see [[retire-minikube]].

## Sync Policy

**Workload applications sync automatically** (`automated`, `selfHeal: false`): a merge to `main` reaches the cluster on its own, within ArgoCD's reconciliation interval. The human gate is the PR review and merge — both behind [[authentik]] SSO with TOTP, the same factor that gates a privileged dispatch — so the second confirmation a manual sync used to provide was a repeat of a decision already made, not an independent check.

`selfHeal` is **off** everywhere: hand-applied drift is not reverted, and several resources are manual by design (`repo-creds-forge`, the `immich-db` Secret).

`prune` is **on for the thirteen generator-backed apps below and off everywhere else**. Where it is off, removing a resource from git does not delete it from the cluster, and deletions stay a deliberate `argocd app sync --prune` — run from gilbert or through the `prune` input on the [[request-a-privileged-run|ArgoCD Deploy]] workflow.

**Never spell the defaults** (`prune: false`, `selfHeal: false`) in an Application manifest. The application controller round-trips the Application spec through its Go structs — where both fields are `omitempty` — every time it initiates an automated sync, so explicit-false fields vanish from the live object the first time the app auto-syncs. The `apps` root then sees a field-level diff it can never reconcile and flaps `OutOfSync` (the 2026-08-18 `ArgoCDAppOutOfSync` episode: `talos` auto-synced during a release blitz and its live CR normalized to `automated: {}`). Write `automated: {}` for plain automated sync, and only add `prune: true` where intended.

### Orphan ConfigMaps from generators

Thirteen apps render their config through a kustomize `configMapGenerator`, which appends a content hash to the ConfigMap name so that editing the content rolls the pods. Under `prune: false` the superseded ConfigMap was never deleted, ArgoCD counted it as pending-prune, and **the app read `OutOfSync` indefinitely** — tripping `ArgoCDAppOutOfSync` on a merge that deployed exactly as intended, and stranding another ConfigMap on every later content edit.

These thirteen therefore carry `prune: true`:

`alloy-ringtail`, `alloy-tracing-ringtail`, `frigate`, `grafana-ringtail`, `homepage`, `kiwix-ringtail`, `loki-ringtail`, `ntfy`, `ollama`, `prometheus-ringtail`, `prowler-ringtail`, `tempo-ringtail`, `unpoller-ringtail`

The cost is the general one: a resource dropped from git under one of these apps is deleted from the cluster on the next sync, rather than lingering. That is the intended trade — the alternative was an alert that flaps on every correct config edit. Nothing else changes, because ArgoCD prunes only what it *tracks*: resources created by a controller rather than by ArgoCD (an [[external-secrets]] `Secret`, say) carry no tracking label and are not candidates.

Tracking is label-based (`app.kubernetes.io/instance`; no `resourceTrackingMethod` is configured, so ArgoCD's default applies). Five of the thirteen share the `monitoring` namespace and two share `alloy`, but each Application has a distinct name and therefore a distinct label, so they do not prune each other's resources.

The [[request-a-privileged-run|ArgoCD Deploy]] `prune` input remains the route for the apps that keep `prune: false`.

Four applications remain **manual**, each for a stated reason in its manifest:

| Application | Why |
|-------------|-----|
| `apps` | The app-of-apps root. A new Application appearing earns a second look, and automated sync here would revert `argocd app set --revision` overrides. |
| `argocd` | Self-management: a manifest that breaks argocd-server breaks the reconciler that would repair it. |
| `cloudnative-pg-ringtail` | Tracks a mutable tag on a mirror, not blumeops `main` — "the revision moved" is not "a human merged". |
| `external-secrets-crds-ringtail` | Same, plus CRD churn under a live operator. |

To pick up newly added Application manifests, sync `apps` explicitly:

```bash
argocd app sync apps
```

### Deploying from a branch

`argocd app set <app> --revision <ref>` still works for pre-merge testing, but on an automated app **always pass a full 40-char SHA, never a branch name**. A branch revision on an automated app means every subsequent push to that branch deploys itself unreviewed. The `ArgoCD Deploy` workflow enforces SHA-or-`main` for exactly this reason; hand-run commands should match it. Reset with `--revision main` when done.

## Authentication

- **SSO via [[authentik]]** — OIDC with a public PKCE client (`argocd`), shared by the web UI and CLI: `argocd login argocd.ops.eblu.me --sso`. The Authentik `admins` group maps to `role:admin` via the RBAC ConfigMap; the default policy grants no access.
- **Local admin** — break-glass password in 1Password (blumeops vault), for when Authentik is down.

The git deploy key (SSH) is injected via [[external-secrets]].

## Related

- [[argocd-cli]] - CLI usage and deployment workflows
- [[apps|Apps]] - Full application registry
- [[forgejo]] - Git source
- [[authentik]] - OIDC identity provider for SSO
- [[federated-login]] - How authentication works across BlumeOps
