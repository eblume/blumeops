---
title: Forgejo
modified: 2026-04-17
tags:
  - service
  - git
  - ci-cd
---

# Forgejo

Git forge and CI/CD platform. **Primary source of truth for blumeops** (mirrored to GitHub).

Built from source on indri, managed via Ansible + mcquack LaunchAgent. Source cloned from Codeberg with a forge mirror as secondary remote.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL (public)** | https://forge.eblu.me |
| **URL (internal)** | https://forge.ops.eblu.me |
| **SSH** | `ssh://forgejo@forge.ops.eblu.me:2222` |
| **Local Ports** | 3001 (HTTP), 2200 (SSH) |
| **Config** | `ansible/roles/forgejo/templates/app.ini.j2` |
| **Binary** | `~/code/3rd/forgejo/forgejo` (source-built) |
| **Data** | `~/forgejo` |
| **LaunchAgent** | `mcquack.eblume.forgejo` |
| **Source** | `~/code/3rd/forgejo` (cloned from Codeberg) |

## Building from Source

Forgejo is built from source on indri, matching the pattern used by [[zot]], [[caddy]], and [[alloy]].

**One-time setup:**

```fish
# Clone from Codeberg (avoids circular dependency with forge)
ssh indri 'git clone https://codeberg.org/forgejo/forgejo.git ~/code/3rd/forgejo'

# Add forge mirror as secondary remote
ssh indri 'cd ~/code/3rd/forgejo && git remote add forge https://forge.eblu.me/mirrors/forgejo.git'
```

**Building a specific version:**

```fish
ssh indri 'cd ~/code/3rd/forgejo && git fetch --tags && git checkout v14.0.3'
ssh indri 'cd ~/code/3rd/forgejo && mise run build'
```

The `build` mise task (defined in the repo's `mise.toml`) runs `make build` with the correct tags and creates the `./forgejo` hardlink. It uses `go@1.25.8` and `node@24` as configured by `mise use`.

**WARNING:** Do NOT use `make forgejo` directly — it rebuilds with empty TAGS, stripping SQLite support. Always use `mise run build` or pass TAGS explicitly to `make build` and `ln -f gitea forgejo` afterwards.

Build tags: `bindata` (embed assets), `timetzdata` (embed timezone data), `sqlite sqlite_unlock_notify` (SQLite support).

After building, run `mise run provision-indri -- --tags forgejo` to deploy the config and restart the service.

## Repositories

| Repo | Description |
|------|-------------|
| `eblume/blumeops` | Infrastructure as code (primary) |
| `eblume/alloy` | Grafana Alloy fork (CGO build) |
| `eblume/tesla_auth` | Tesla OAuth helper |

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
- `runner_k8s_uuid`, `runner_k8s_token` - Static credentials for the k8s runner `server.connections` flow

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
- **Archive redirect:** Archive endpoints (`/*/archive/*`) are 302-redirected to `forge.ops.eblu.me` — prevents unauthenticated crawlers from triggering unbounded git bundle generation (known DoS vector, see [[flyio-proxy#Crawler Mitigation]])
- **robots.txt:** Blocks crawlers from `/mirrors/`, `/user/`, `/users/`, `/*/archive/`, `/*/releases/download/`
- **OAuth dead-end:** "Sign in with Authentik" redirects to the (tailnet-only) Authentik URL — SSO only works from the tailnet

### Break-glass

`mise run fly-shutoff` stops all public traffic immediately. forge.ops.eblu.me continues to work from the tailnet. See [[expose-service-publicly#Break-glass shutoff]].

## Monitoring

Forgejo exposes a Prometheus `/metrics` endpoint (enabled via `[metrics]` in `app.ini`). Alloy on indri scrapes it at `localhost:3001/metrics`. Metrics are mostly Go runtime stats and repo counters (no per-request latency histogram).

Request latency is measured at the Fly.io proxy layer via the `flyio_nginx_upstream_response_time_seconds` histogram, visible on the Forgejo Grafana dashboard under "Forgejo: Upstream Response Time".

### Archive Cleanup

The `[cron.archive_cleanup]` section is enabled with `OLDER_THAN = 2h` and `RUN_AT_START = true`. This prevents the `repo-archive/` directory from growing unboundedly when crawlers or users trigger archive downloads. Without this, the directory grew to 54GB in 2 days during a crawler incident in April 2026.

## Mirrors

Forgejo hosts pull mirrors of external repositories (GitHub, etc.) for supply chain control. Mirrors live in the `mirrors/` org and sync on a configurable interval. See [[manage-forgejo-mirrors]] for operations.

## Related

- [[forgejo-runner]] - k8s CI/CD runner (minikube on indri)
- [[argocd]] - Uses Forgejo as git source
- [[authentik]] - OIDC identity provider
- [[zot]] - Container registry for built images
