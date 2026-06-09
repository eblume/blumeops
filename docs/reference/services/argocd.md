---
title: ArgoCD
modified: 2026-06-09
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

A single ArgoCD instance (on indri's minikube) manages both clusters:

| Cluster | Destination | Apps |
|---------|-------------|------|
| minikube (indri) | `https://kubernetes.default.svc` | Most services |
| k3s ([[ringtail]]) | `https://ringtail.tail8d86e.ts.net:6443` | GPU workloads and `*-ringtail` apps |

## Sync Policy

All applications use **manual sync** — including the `apps` app-of-apps root. To pick up newly added Application manifests, sync `apps` explicitly:

```bash
argocd app sync apps
```

This gives explicit control over every deployment; nothing rolls out on push alone.

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
