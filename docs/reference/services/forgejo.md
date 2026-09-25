---
title: Forgejo
modified: 2026-09-25
last-reviewed: 2026-08-29
tags:
  - service
  - git
  - ci-cd
---

# Forgejo

Git forge and CI/CD platform. **Primary source of truth for blumeops** (mirrored to GitHub).

Built from source on indri. The LaunchAgent unit is nix-managed ([[indri]] flake, PR 8 of the nix-darwin series); the build, the `app.ini` and the version stay with the Ansible role. The build pulls from the forge mirror (`origin`); Codeberg is the upstream remote (`codeberg`). To upgrade, see [[upgrade-forgejo]].

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
| **LaunchAgent** | `mcquack.eblume.forgejo` (unit nix-managed — [[indri]] §Maintenance Notes) |
| **Source** | `~/code/3rd/forgejo` (`origin` = forge mirror, `codeberg` = upstream) |

## Building from Source

Forgejo is built from source on indri, matching the pattern used by [[zot]], [[caddy]], and [[alloy]].

**Remotes:** `origin` → `https://forge.ops.eblu.me/mirrors/forgejo.git` (the
build source), `codeberg` → `https://codeberg.org/forgejo/forgejo.git`
(upstream). The original clone was from Codeberg to avoid a circular dependency
with the forge; the mirror was later promoted to `origin`.

**Version is declared in the Ansible role**, not built ad-hoc. `forgejo_version`
(plus `forgejo_node_version`/`forgejo_build_tags`) in
`ansible/roles/forgejo/defaults/main.yml` pins the deployed tag. On
`provision-indri --tags forgejo` the role fetches from the mirror, checks out the
tag, rebuilds **only when the running binary doesn't match**, links `./forgejo`,
and restarts. Bumping `forgejo_version` in a PR is therefore the whole upgrade —
reproducible and DR-safe. See [[upgrade-forgejo]] for the full procedure (DB
backup, breaking changes, verification, rollback).

**WARNING:** Do NOT use `make forgejo` directly — it rebuilds with empty TAGS, stripping SQLite support. The role passes `TAGS` explicitly to `make build` and `ln -f gitea forgejo` afterwards.

Build tags (`forgejo_build_tags`): `bindata` (embed assets), `timetzdata` (embed timezone data), `sqlite sqlite_unlock_notify` (SQLite support).

> go comes from the indri global mise baseline (declared in the indri flake's
> mise config, `darwin/indri/configuration.nix`) — `GOTOOLCHAIN=auto`
> switches per go.mod and that config keeps mise's `GOROOT` export off, so a
> plain `make build` works at any tag ([[upgrade-forgejo]] §Go toolchain).
> The role removes the checkout's untracked `mise.toml`, which used to pin a
> stale go.

## Repositories

The forge has three namespaces:

- `eblume/` — first-party repos (blumeops, talos, hephaestus, myeve,
  gamedev, …). The forge is the primary source of truth for blumeops.
- `agents/` — the [[agents-forgejo-bot]]'s forks (blumeops, agents,
  horkos); the push target for repos where the human gate is the point.
- `mirrors/` — pull mirrors of external repos (alloy, tesla_auth, …)
  for supply chain control; see [[manage-forgejo-mirrors]].

## CI/CD (Forgejo Actions)

**Runners:**

| Runner | Host | Labels | Purpose |
|--------|------|--------|---------|
| `indri-runner` | [[indri]] (native, host-mode) | `indri` | Default jobs; Dagger CLI talks to the Docker Desktop engine |
| `ringtail-nix-builder` | [[ringtail]] (NixOS) | `nix-container-builder` | Nix container builds via `nix-build` + `skopeo` |
| `ringtail-priv-runner` | [[ringtail]] (NixOS, sandboxed `horkos-runner`) | `priv` | Warrant-gated, dispatch-only privileged jobs ([[warrant-approval-gated-runs]]) |

**Workflows** in `.forgejo/workflows/`:

| Workflow | Trigger | Runner | Purpose |
|----------|---------|--------|---------|
| `agent-repo-access` | push/PR/dispatch | `indri` | Reconcile the `agents` bot's collaborations + labels against repos.json |
| `argocd-deploy` | dispatch | `priv` | Warrant-gated ArgoCD deploy of a single app |
| `argocd-sync-apps` | dispatch | `priv` | Warrant-gated sync of the app-of-apps root (`apps`) |
| `branch-cleanup` | cron/dispatch | `indri` | Delete stale branches |
| `build-blumeops` | dispatch | `indri` | Docs build + release |
| `build-container` | push (main)/PR | `indri` → `nix-container-builder` | Nix container image builds; classify on indri, build on the nix builder ([[build-container-image]]) |
| `deploy-fly` | dispatch | `priv` | Warrant-gated deploy of the Fly.io proxy ([[flyio-proxy]]) |
| `docs-checks` | PR/push | `indri` | Docs + changelog validation |
| `flake-update` | dispatch | `nix-container-builder` | Ringtail flake input update (native nix on the ringtail nix runner) |
| `lint` | PR/push | `indri` | Repo lint (prek hooks) |
| `provision-indri` | dispatch | `indri` | Warrant-gated apply of a bound SHA's nix-darwin generation; fire-and-forget — green means the switch launched ([[provision]]) |
| `run-script` | dispatch | `priv` | Warrant-gated one-off script run |
| `horkos-forge-drift` | cron/push/dispatch | `indri` | Weekly drift check on horkos-forge's grants |

PR jobs additionally end with the shared `.forgejo/actions/report-failure`
composite action: on failure it posts the job's teed log tail to the PR as
`forgejo-actions` — a triggering COMMENT review on agent-authored PRs (the
talos fix loop), a plain comment otherwise — deduped per (workflow, job, matrix leg, head SHA)
and capped at three failure reviews per PR ([[agent-change-process#CI failure notices]]).

(Until [[retire-minikube]] a `k8s` runner was a minikube DinD pod that also built Dockerfile/Dagger containers; that path is retired.)

## Secrets (Forgejo Config)

Server configuration secrets managed via 1Password → Ansible (fetched in
the indri playbook `pre_tasks`):

- `lfs-jwt-secret`, `internal-token`, `oauth2-jwt-secret` — Forgejo server tokens (rendered into `app.ini`)
- `runner_reg` — instance-global runner registration token, written to `/etc/forgejo-runner/token.env` for the two ringtail runners

Per-runner identity and job-credential secrets live on the runner card ([[forgejo-runner#Credentials]]).

## Forgejo Actions Secrets

Repository-level Actions secrets are synced from 1Password to Forgejo by
the `forgejo_actions_secrets` Ansible role (human-run from gilbert under
biometric `op` — the role authenticates with the scoped eblume
write:repository PAT and the step never leaves a human). The sync is
authoritative: declared secrets are PUT (created/updated), undeclared live
ones are DELETEd, and `--check` reports name-level drift — values are
write-only, so value drift is invisible to the role):

```bash
mise run provision-indri -- --tags forgejo_actions_secrets
```

| Repo | Secrets | Purpose |
|------|---------|---------|
| `eblume/blumeops` | `FORGE_REPO_WRITE_TOKEN`, `BLUMEOPS_CI_OP_TOKEN` | `agent-repo-access` reconcile + `horkos-forge-drift` reads (write:repository,read:user eblume PAT); job-time `op read` of blumeops-ci items |
| `eblume/talos`, `eblume/horkos` | `ZOT_PUSH_API_KEY` | Auto-release CI: per-repo push-only zot identity (`ci-zot-talos` / `ci-zot-horkos`), provisioned from the zot master fields by the role |
| `eblume/cv` | — (none) | Release CI is stored-secret-free; the empty declaration makes provisioning authoritative here (first run deletes the stale `FORGE_TOKEN`) |

The per-purpose secrets the role used to sync (argocd token, fly deploy
token, zot CI key, main-push PAT) are no longer Forgejo secrets: workflows
`op read` the blumeops-ci items at job time with `BLUMEOPS_CI_OP_TOKEN` —
see [[blumeops-ci-item-migration]].

These secrets are injected as `${{ secrets.SECRET_NAME }}` in workflow files.

### API Tokens

The role authenticates with an **eblume** PAT scoped to
`write:repository,read:user` (1Password item `forge-repo-write-token` —
the same token CI holds as `FORGE_REPO_WRITE_TOKEN`). Its repo-admin
endpoints (collaborator / Actions-secret ops) work with that scope because
eblume owns the repos; the site-admin token is never needed here. Mint it
on indri with `forgejo admin user generate-access-token … --scopes
write:repository,read:user` and store the value in 1Password →
`forge-repo-write-token` → `token`.

The site-admin PAT (`api-token` in the "Forgejo Secrets" item) is **not**
used by this role anymore. Its remaining consumers:

- `mise run runner-logs` (reads from 1Password at run time)
- The `tea` CLI (**copies the token** into `~/.config/tea/config.yml`; re-paste it there after rotation). tea switched to this PAT 2026-07-04 after its OAuth token expired and tea 0.14.2 broke httpsign auth ([tea#1046](https://gitea.com/gitea/tea/issues/1046) — fixed in go-sdk but unreleased; httpsign can be re-enabled in tea's config once 0.14.3 ships).
- the `forgejo_metrics` role (fetched as `forgejo_metrics_api_key` in the playbook pre_tasks)

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

### Database hygiene

The SQLite database (`data/forgejo.db`) does not shrink on its own: deletes
only mark pages reusable. Two crons bound the tables that grow unbounded:

- `[cron.delete_old_system_notices]` — weekly (`@every 168h`,
  `RUN_AT_START = true`), drops system notices older than
  `forgejo_old_notices_retention` (default `720h`, 30 days). The `notice`
  table had grown to 146k rows of pure history (mirror-sync failures,
  closed-pipe webhooks) before this.
- `[cron.delete_old_actions]` — weekly, drops activity-feed (`action`
  table) entries older than `forgejo_old_actions_retention` (default
  `2160h`, 90 days). **Caveat:** this deletes the *whole* feed older than
  the cutoff — dashboard timeline and profile heatmap included, not just
  the mirror-sync rows — and Forgejo has no per-org switch for mirror-sync
  feed entries. The `mirrors` user's sync events dominated the table
  (~40M/month of full commit lists). 90 days was chosen because the feed is
  rarely consulted and git history is the record; raise the retention if a
  longer feed is wanted.

Neither cron shrinks the file. To reclaim space, stop Forgejo and run
`sqlite3 ~/forgejo/data/forgejo.db 'VACUUM;'` during a quiet window (same
window shape as [[upgrade-forgejo]]). Upgrade-time `forgejo.db.bak-*`
copies are deleted once the upgrade proves out; borgmatic already holds
nightly DB dumps.

`[cron.git_gc_repos]` is deliberately left disabled (Forgejo default).
`eblume/blumeops.git` had 47 packs / 1,209 loose objects at the time of
writing — moderate, and git's own auto-gc bounds it. If the loose-object
count keeps climbing, enable it:

```ini
[cron.git_gc_repos]
ENABLED = true
RUN_AT_START = true
SCHEDULE = @every 168h
```

## Mirrors

Forgejo hosts pull mirrors of external repositories (GitHub, etc.) for supply chain control. Mirrors live in the `mirrors/` org and sync on a configurable interval. See [[manage-forgejo-mirrors]] for operations.

## Related

- [[upgrade-forgejo]] - Version upgrade procedure (DB backup, breaking changes, rollback)
- [[forgejo-runner]] - CI/CD runners (indri + ringtail instances, credentials)
- [[agents-forgejo-bot]] - The bot identity behind the agents/ namespace
- [[argocd]] - Uses Forgejo as git source
- [[authentik]] - OIDC identity provider
- [[zot]] - Container registry for built images
