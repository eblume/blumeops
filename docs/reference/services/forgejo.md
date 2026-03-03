---
title: Forgejo
modified: 2026-03-03
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
| **URL (public)** | https://forge.eblu.me |
| **URL (internal)** | https://forge.ops.eblu.me |
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

1. Go to https://forge.eblu.me/user/settings/applications
2. Create a new token with `write:repository` scope
3. Store it in 1Password → "Forgejo Secrets" item → `api-token` field

This is a bootstrapping requirement - the PAT enables IaC for all other secrets.

## Identity Provider

[[authentik]] is the BlumeOps OIDC identity provider and source of truth for user identity. Forgejo authenticates against Authentik as an OIDC client.

**Configuration:**
- OAuth2 provider and application defined in Authentik blueprints (`argocd/manifests/authentik/configmap-blueprint.yaml`)
- Auth source created via `forgejo admin auth add-oauth` with `--skip-local-2fa` (lives in Forgejo's SQLite database, not app.ini)
- `[oauth2_client]` section in `app.ini.j2` controls auto-registration and account linking behavior

**MFA:** SSO logins skip Forgejo's local 2FA (`--skip-local-2fa` on the auth source) — Authentik enforces MFA instead. Local password logins still require Forgejo's own TOTP. Note: the `--skip-local-2fa` CLI flag has a [known bug](https://codeberg.org/forgejo/forgejo/issues/5366) where it doesn't persist via `update-oauth`; it was set directly in the `login_source.cfg` JSON (`SkipLocalTwoFA: true`).

**Account linking:** `ACCOUNT_LINKING = login` — when an Authentik user's email matches an existing local account, Forgejo prompts for the local password (and local MFA) to confirm the link. This is a one-time operation that preserves existing accounts, API tokens, SSH keys, and repository ownership.

**Group-based admin:** The `admins` group in Authentik maps to Forgejo admin status via `--admin-group admins` on the auth source. Manage admin access in Authentik, not Forgejo.

**Break-glass:** Local password login always works (with local MFA). Authentik SSO is additive — if Authentik is down, log in with local credentials.

## Public Access

Forgejo is publicly accessible at `https://forge.eblu.me` via [[flyio-proxy]]. This is the first dynamic, authenticated service exposed publicly.

| Access Method | URL | Reachable From |
|---------------|-----|----------------|
| **HTTPS (public)** | https://forge.eblu.me | Public internet |
| **HTTPS (internal)** | https://forge.ops.eblu.me | Tailnet only |
| **SSH** | `ssh://forgejo@forge.ops.eblu.me:2222` | Tailnet only |

The UI shows `forge.eblu.me` for HTTPS clone URLs and `forge.ops.eblu.me` for SSH clone URLs.

### Security Controls

- **Registration:** Local registration disabled; only [[authentik]] SSO login allowed (`ALLOW_ONLY_EXTERNAL_REGISTRATION = true`)
- **Reverse proxy trust:** `REVERSE_PROXY_LIMIT = 2`, `REVERSE_PROXY_TRUSTED_PROXIES = *` — Forgejo logs the real client IP from `X-Real-IP` header, not the proxy's Tailscale IP
- **Rate limiting:** nginx rate limits login/signup/forgot-password endpoints (3r/s per client IP via `Fly-Client-IP` header)
- **fail2ban:** Runs in the Fly.io container; bans IPs after 5 failed logins in 10 minutes via nginx deny list (ephemeral across deploys)
- **Swagger:** Blocked at the proxy (`/swagger` returns 403); use forge.ops.eblu.me for API access
- **OAuth dead-end:** "Sign in with Authentik" redirects to the (tailnet-only) Authentik URL — SSO only works from the tailnet

### Break-glass

`mise run fly-shutoff` stops all public traffic immediately. forge.ops.eblu.me continues to work from the tailnet. See [[expose-service-publicly#Break-glass shutoff]].

## Related

- [[argocd]] - Uses Forgejo as git source
- [[authentik]] - OIDC identity provider
- [[zot]] - Container registry for built images
