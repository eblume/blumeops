---
title: ArgoCD CLI
modified: 2026-10-31
last-reviewed: 2026-10-31
tags:
  - reference
  - gitops
  - argocd
---

# ArgoCD CLI

Command-line workflows for deploying and managing applications via [[argocd]].

## CLI Commands

```bash
argocd app list                # List all applications and sync status
argocd app get <app>           # Show app details, health, and resources
argocd app diff <app>          # Preview what would change on sync
argocd app sync <app>          # Apply pending changes
argocd app sync apps           # Sync the app-of-apps (picks up new Application manifests)
```

## Login

Default (Authentik SSO, PKCE, opens browser):

```bash
argocd login argocd.ops.eblu.me --sso
```

Break-glass admin login (only if Authentik is down):

```bash
argocd login argocd.ops.eblu.me \
  --username admin \
  --password "$(op read 'op://vg6xf6vvfmoh5hqjjhlhbeoaie/srogeebssulhtb6tnqd7ls6qey/password')"
```

## Availability

The CLI is installed on both gilbert and ringtail. On ringtail it comes from
the NixOS flake (`environment.systemPackages`, next to `tea`); the same
package backs the priv runner's `hostPackages`, so re-check CLI/server skew
against `service-versions.yaml` on each flake bump.

## Branch-Testing Workflow

Test a pre-merge change on a workload app. Workload apps are `automated` with
`selfHeal: false`, so a branch name as revision would deploy every later push
to that branch unreviewed. Pin a full 40-character SHA, never a branch name
([[argocd#Deploying from a branch]]):

```bash
# 1. Point the app at the PR head (full 40-char SHA)
argocd app set <service> --revision <sha>

# 2. Sync to deploy that revision
argocd app sync <service>

# 3. Test the changes...

# 4. Reset to main. Automated apps then follow main on their own; do not sync after the merge.
argocd app set <service> --revision main
```

Whether ArgoCD resolves a pre-merge PR-head SHA is still unverified
([[argocd#SHA reachability (pre-merge PR heads)]]). If `app set` rejects the
SHA, the pre-merge test is blocked; do not fall back to a branch name.

## Related

- [[argocd]] — Service reference (URLs, credentials, sync policy)
- [[apps]] — Full application registry
- [[forgejo]] — Git source
