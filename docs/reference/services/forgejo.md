---
title: forgejo
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
- `build-blumeops.yaml` - Documentation builds and releases

## Secrets (Forgejo Config)

Server configuration secrets managed via 1Password → Ansible:
- `lfs-jwt-secret`, `internal-token`, `oauth2-jwt-secret` - Forgejo server tokens
- `runner_reg` - Runner registration token (also in k8s via [[external-secrets]])

## Forgejo Actions Secrets

Repository-level secrets for CI/CD workflows. **Not IaC** - managed in Forgejo UI at:
`Settings → Actions → Secrets`

| Secret | Used By | Purpose |
|--------|---------|---------|
| `ARGOCD_AUTH_TOKEN` | `build-blumeops.yaml` | Sync docs app after release |

These secrets are injected as `${{ secrets.SECRET_NAME }}` in workflow files.

> **Note:** These secrets are also stored in 1Password ("Forgejo Secrets" item) as the source of truth, but were manually copied to Forgejo. They will not auto-update if the 1Password value changes.

## Related

- [[argocd]] - Uses Forgejo as git source
- [[zot]] - Container registry for built images
