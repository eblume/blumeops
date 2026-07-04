---
title: Forgejo
modified: 2026-06-17
tags:
  - service
  - git
  - ci-cd
---

# Forgejo

Git forge and CI/CD platform. **Primary source of truth for blumeops** (mirrored to GitHub).

Built from source on indri, managed via Ansible + mcquack LaunchAgent. The build pulls from the forge mirror (`origin`); Codeberg is the upstream remote (`codeberg`). To upgrade, see [[upgrade-forgejo]].

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
| **Source** | `~/code/3rd/forgejo` (`origin` = forge mirror, `codeberg` = upstream) |

## Building from Source

Forgejo is built from source on indri, matching the pattern used by [[zot]], [[caddy]], and [[alloy]].

**Remotes:** `origin` → `https://forge.ops.eblu.me/mirrors/forgejo.git` (the
build source), `codeberg` → `https://codeberg.org/forgejo/forgejo.git`
(upstream). The original clone was from Codeberg to avoid a circular dependency
with the forge; the mirror was later promoted to `origin`.

**Version is declared in the Ansible role**, not built ad-hoc. `forgejo_version`
(plus `forgejo_go_version`/`forgejo_node_version`/`forgejo_build_tags`) in
`ansible/roles/forgejo/defaults/main.yml` pins the deployed tag. On
`provision-indri --tags forgejo` the role fetches from the mirror, checks out the
tag, rebuilds **only when the running binary doesn't match**, links `./forgejo`,
and restarts. Bumping `forgejo_version` in a PR is therefore the whole upgrade —
reproducible and DR-safe. See [[upgrade-forgejo]] for the full procedure (DB
backup, breaking changes, verification, rollback).

**WARNING:** Do NOT use `make forgejo` directly — it rebuilds with empty TAGS, stripping SQLite support. The role passes `TAGS` explicitly to `make build` and `ln -f gitea forgejo` afterwards.

Build tags (`forgejo_build_tags`): `bindata` (embed assets), `timetzdata` (embed timezone data), `sqlite sqlite_unlock_notify` (SQLite support).

> The repo's local `mise.toml` (`mise run build`) is untracked and pins go 1.25.8 — it fails on v15+. The role builds with `mise x go@{{ forgejo_go_version }}` instead; use that form for manual builds too.

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
| `indri-runner` | [[indri]] (native, host-mode) | `k8s` (compat), `indri` | Lightweight jobs; Dagger CLI talks to the Docker Desktop engine |
| `nix-container-builder` | [[ringtail]] (NixOS) | `nix-container-builder` | Nix container builds via `nix-build` + `skopeo` |

**Workflows:** `.forgejo/workflows/`
- `build-container.yaml` - Nix container builds (manual dispatch; classify on `k8s`, build on `nix-container-builder`)
- `build-blumeops.yaml` - Documentation builds and releases

`build-container.yaml` is manual-dispatch only and nix-only: it builds `containers/<name>/default.nix` on the `nix-container-builder` runner. See [[build-container-image]]. (Until [[retire-minikube]] the `k8s` runner was a minikube DinD pod that also built Dockerfile/Dagger containers; that path was retired.)

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

**Consumers — update all of these when rotating the token:**

- The Ansible role (reads from 1Password at provision time)
- `mise run runner-logs` (reads from 1Password at run time)
- The `tea` CLI (**copies the token** into `~/.config/tea/config.yml`; re-paste it there after rotation). tea switched to this PAT 2026-07-04 after its OAuth token expired and tea 0.14.2 broke httpsign auth ([tea#1046](https://gitea.com/gitea/tea/issues/1046) — fixed in go-sdk but unreleased; httpsign can be re-enabled in tea's config once 0.14.3 ships).

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

- [[upgrade-forgejo]] - Version upgrade procedure (DB backup, breaking changes, rollback)
- [[forgejo-runner]] - k8s CI/CD runner (minikube on indri)
- [[argocd]] - Uses Forgejo as git source
- [[authentik]] - OIDC identity provider
- [[zot]] - Container registry for built images
