---
title: Forgejo
modified: 2026-02-19
tags:
  - service
  - git
  - ci-cd
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

**Runners:**

| Runner | Host | Labels | Purpose |
|--------|------|--------|---------|
| k8s DinD pod | [[indri]] (minikube) | `k8s` | Dockerfile builds via Dagger |
| ringtail-nix-builder | [[ringtail]] (native) | `nix-container-builder` | Nix builds via `nix-build` + `skopeo` |

**Workflows:** `.forgejo/workflows/`
- `build-container.yaml` - Dockerfile builds on tag (runs on `k8s`)
- `build-container-nix.yaml` - Nix builds on tag (runs on `nix-container-builder`)
- `build-blumeops.yaml` - Documentation builds and releases

Both container workflows trigger on the same tag pattern (`*-v[0-9]*`). Each checks for its build file (`Dockerfile` or `default.nix`) and skips if not present. See [[build-container-image]].

## Secrets (Forgejo Config)

Server configuration secrets managed via 1Password → Ansible:
- `lfs-jwt-secret`, `internal-token`, `oauth2-jwt-secret` - Forgejo server tokens
- `runner_reg` - Runner registration token (also in k8s via [[external-secrets]])

## Forgejo Actions Secrets

Repository-level secrets for CI/CD workflows, synced from 1Password via Ansible.

| Secret | 1Password Field | Used By | Purpose |
|--------|-----------------|---------|---------|
| `ARGOCD_AUTH_TOKEN` | `argocd_token` | `build-blumeops.yaml` | Sync docs app after release |

These secrets are injected as `${{ secrets.SECRET_NAME }}` in workflow files.

**IaC:** The `forgejo_actions_secrets` Ansible role syncs these secrets from 1Password to Forgejo via the Forgejo API. Run with:

```bash
mise run provision-indri -- --tags forgejo_actions_secrets
```

### API Token Setup (Manual, One-Time)

The Ansible role authenticates to the Forgejo API using a Personal Access Token (PAT). This PAT must be created manually:

1. Go to https://forge.ops.eblu.me/user/settings/applications
2. Create a new token with `write:repository` scope
3. Store it in 1Password → "Forgejo Secrets" item → `api-token` field

This is a bootstrapping requirement - the PAT enables IaC for all other secrets.

## Identity Provider

[[authentik]] is the BlumeOps OIDC identity provider and source of truth for user identity. Forgejo will eventually authenticate against Authentik as an OIDC client, with user provisioning managed in Authentik. This migration is deferred — the existing `eblume` account has extensive automations that need careful migration.

## Future: Public Access

Forgejo can be exposed publicly at `forge.eblu.me` via [[flyio-proxy]]. Since Forgejo runs natively on [[indri]] (not in k8s), the pattern is:

1. Create a k8s ExternalName Service pointing to indri's Tailscale IP
2. Create a Tailscale Ingress with `tailscale.com/tags: "tag:k8s,tag:flyio-target"`
3. Add the nginx server block and DNS CNAME

Exposing a dynamic, authenticated service like Forgejo requires a full security review before going live:

- Disable open user registration (require invites or admin approval)
- Configure fail2ban on indri with a filter for Forgejo's log format
- Ensure Forgejo logs the forwarded client IP (`X-Real-IP`) rather than the proxy's Tailscale IP
- Audit repository visibility defaults and permissions
- Rehearse the break-glass shutoff (`mise run fly-shutoff`)

See [[expose-service-publicly]] for the full howto and dynamic service checklist.

## Related

- [[argocd]] - Uses Forgejo as git source
- [[authentik]] - OIDC identity provider
- [[zot]] - Container registry for built images
