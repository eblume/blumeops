---
title: ArgoCD
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
| **Git Source** | `ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git` |
| **Manifests Path** | `argocd/` |

## Sync Policy

| Application | Sync Policy | Rationale |
|-------------|-------------|-----------|
| `apps` | Automated | Picks up new Application manifests |
| All workloads | Manual | Explicit control over deployments |

## Credentials

- Admin password: 1Password (blumeops vault)
- Git deploy key (SSH): 1Password

## Related

- [[apps|Apps]] - Full application registry
- [[forgejo]] - Git source
