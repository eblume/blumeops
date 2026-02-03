---
title: Forgejo
tags:
  - service
  - git
  - cicd
---

# Forgejo

Git forge and CI/CD platform. **Primary source of truth for blumeops** (mirrored to GitHub).

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://forge.ops.eblu.me |
| **SSH** | `ssh://forgejo@forge.ops.eblu.me:2222` |
| **Local Ports** | 3001 (HTTP), 2200 (SSH) |
| **Config** | `ansible/roles/forgejo/templates/app.ini.j2` |

## Repositories

| Repo | Description |
|------|-------------|
| `eblume/blumeops` | Infrastructure as code (primary) |
| `eblume/alloy` | Grafana Alloy fork (CGO build) |
| `eblume/tesla_auth` | Tesla OAuth helper |
| Helm chart mirrors | cloudnative-pg-charts, grafana-helm-charts |

## CI/CD (Forgejo Actions)

**Runner:** Kubernetes pod with Docker-in-Docker sidecar
- Namespace: `forgejo-runner`
- Labels: `k8s`
- ArgoCD app: `forgejo-runner`

**Workflows:** `.forgejo/workflows/`
- `build-container.yaml` - Container image builds on tag

## Secrets

Managed via 1Password: `lfs-jwt-secret`, `internal-token`, `oauth2-jwt-secret`, `runner_reg`

## Related

- [[reference/services/argocd|ArgoCD]] - Uses Forgejo as git source
- [[reference/services/zot|Zot]] - Container registry for built images
