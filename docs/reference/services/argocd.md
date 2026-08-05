---
title: ArgoCD
modified: 2026-08-05
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

**Workload applications sync automatically** (`automated: {prune: false, selfHeal: false}`): a merge to `main` reaches the cluster on its own, within ArgoCD's reconciliation interval. The human gate is the PR review and merge — both behind [[authentik]] SSO with TOTP, the same factor that gates a privileged dispatch — so the second confirmation a manual sync used to provide was a repeat of a decision already made, not an independent check.

`prune` and `selfHeal` are both **off**. Removing a resource from git does not delete it from the cluster, and hand-applied drift is not reverted — several resources are manual by design (`repo-creds-forge`, the `immich-db` Secret). Deletions stay a deliberate `argocd app sync --prune`.

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
