---
title: ArgoCD CLI
modified: 2026-09-04
last-reviewed: 2026-04-01
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

Test changes from a feature branch before merging:

```bash
# 1. Point the app at your branch
argocd app set <service> --revision <branch>

# 2. Sync to deploy the branch version
argocd app sync <service>

# 3. Test the changes...

# 4. After merge, reset to main and sync
argocd app set <service> --revision main
argocd app sync <service>
```

## Related

- [[argocd]] — Service reference (URLs, credentials, sync policy)
- [[apps]] — Full application registry
- [[forgejo]] — Git source
