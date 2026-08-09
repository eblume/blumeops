---
title: Upgrade Forgejo
modified: 2026-08-09
last-reviewed: 2026-08-09
tags:
  - how-to
  - operations
  - forgejo
---

# Upgrade Forgejo

How to upgrade the source-built [[forgejo]] instance on [[indri]]. Forgejo is
**not** installed via Homebrew — it runs as a source-built binary under the
`mcquack.eblume.forgejo` LaunchAgent, built with the `mise` toolchain (Go +
Node), with `origin` pointing at the **forge mirror**
(`forge.ops.eblu.me/mirrors/forgejo`) and `codeberg` as the upstream remote.

> **Critical infra.** Forgejo is the primary source of truth for blumeops and
> hosts the mirrors the build chain depends on. A restart briefly interrupts
> CI, ArgoCD git sync, and mirror sync. Major-version (`vN` → `vN+1`) upgrades
> run database migrations on first start — back up first and have a human
> watching.

## Pre-upgrade checklist

1. Read the upstream release notes for every version between the deployed
   version and the target — **especially major bumps**, which list breaking
   changes requiring manual intervention:
   `release-notes-published/<version>.md` in the repo, or
   `https://codeberg.org/forgejo/forgejo/releases`.
2. Check `app.ini.j2` for any settings the release removed or renamed.
3. Confirm the database backend: `grep -iA3 '\[database\]' ~/forgejo/custom/conf/app.ini`.
   The instance uses **SQLite3** (`~/forgejo/data/forgejo.db`), so a backup is a
   file copy.

## Procedure

The forgejo Ansible role is **version-driven**: `forgejo_version` in
`ansible/roles/forgejo/defaults/main.yml` declares the deployed tag, and the
role fetches from the mirror, checks out that tag, rebuilds (only when the
running binary doesn't match), and restarts. **Bumping `forgejo_version` in a PR
and re-provisioning IS the upgrade** — reproducible and DR-safe.

Borgmatic already dumps `forgejo.db` (WAL-safe) and the git repositories nightly,
so a recent backup normally exists. For a **major** bump, still take an explicit
same-day snapshot before deploying:

```fish
# 1. Back up the SQLite database (belt and suspenders) while forgejo is up.
ssh indri 'cp ~/forgejo/data/forgejo.db ~/forgejo/data/forgejo.db.bak-(date +%Y%m%d)'

# 2. Bump the pinned version in the role defaults (this is the PR change):
#      forgejo_version: "v16.0.2"
#    For a MAJOR bump, also set forgejo_go_version to match the target tag's
#    go.mod `toolchain` directive (check: git show <tag>:go.mod | head).
#    v16 requires go1.26.5.

# 3. Deploy — fetches, checks out, builds with the pinned toolchain, restarts.
mise run provision-indri -- --tags forgejo
```

> **Go toolchain pin (major bumps).** A source build needs a Go that satisfies
> the tag's `go.mod` `toolchain` directive. mise hard-sets `GOROOT`, which
> defeats `GOTOOLCHAIN=auto` (the auto-switched driver then resolves `compile`
> from the wrong `GOROOT` and fails with `compile: version "goX" does not match
> go tool version "goY"`). The role sidesteps this by building with
> `mise x go@{{ forgejo_go_version }} … env GOTOOLCHAIN=local make build`, so
> **`forgejo_go_version` must be bumped alongside `forgejo_version`** whenever the
> target tag raises its toolchain floor.

### Manual build (fallback / debugging)

```fish
ssh indri 'cd ~/code/3rd/forgejo && git fetch --tags origin && git checkout v16.0.2'
ssh indri 'cd ~/code/3rd/forgejo && mise x go@1.26.5 node@24 -- env GOTOOLCHAIN=local TAGS="bindata timetzdata sqlite sqlite_unlock_notify" make build && ln -f gitea forgejo'
mise run provision-indri -- --tags forgejo   # restart
```

Note: the repo's local `mise.toml` (`mise run build`) is **untracked** and pins
go 1.25.8, so it fails on v15 — prefer the explicit `mise x go@…` form above for
manual builds.

## Post-upgrade verification

```fish
# Version + health
ssh indri '~/code/3rd/forgejo/forgejo --version'
mise run services-check

# Database consistency (recommended after major upgrades)
ssh indri 'cd ~/forgejo && ~/code/3rd/forgejo/forgejo doctor check --run check-db-consistency'
```

Then confirm the dependent paths still work:

- **Web UI / SSO login** at https://forge.ops.eblu.me
- **CI**: trigger or watch a runner job (`mise run runner-logs`)
- **Private-repo job logs** — the check that says the v16 API is live, since
  it is the one thing v15 could not do at all:
  `mise run runner-logs <run#> -j 0 --repo eblume/hephaestus.nvim`. On v15 this
  prints "This forge predates the job-log REST API"; on v16 it prints the log.
- **Mirror sync**: a private-repo API operation still succeeds (see token note
  below)

## v16.0.0 breaking changes (relevant to this instance)

The 15 → 16 major bump carried these; their impact on this deployment:

| Change | Impact here |
|--------|-------------|
| **Repository-based server-side hooks replaced with centralised hooks** ([PR 10397](https://codeberg.org/forgejo/forgejo/pulls/10397)) | The big one. Rewrites hooks in every repository on upgrade. Upstream lists it under ["known problematic versions or upgrade paths"](https://forgejo.org/docs/latest/admin/upgrade/#when-upgrading-from--known-problematic-versions-or-upgrade-paths) — read that section before deploying, and run `forgejo doctor check --run check-db-consistency` after. Verify a push still triggers CI: a broken hook breaks pushes, not just Actions. |
| **Docker default `REVERSE_PROXY_TRUSTED_PROXIES = *` removed** ([PR 12782](https://codeberg.org/forgejo/forgejo/pulls/12782)) | No-op for the upgrade: `app.ini.j2` sets it **explicitly** (with `REVERSE_PROXY_LIMIT = 2`), so nothing changes. Worth noting separately that upstream now treats `*` as unsafe — narrowing it to Caddy's address is its own change, not part of this bump. |
| **git mirror HTTP operations no longer follow redirects** ([PR 13129](https://codeberg.org/forgejo/forgejo/pulls/13129)) | Affects the GitHub mirrors ([[manage-forgejo-mirrors]]). Direct `github.com/<owner>/<repo>` URLs don't redirect, but a *renamed* upstream does — a mirror that silently relied on GitHub's rename redirect will start failing. Check mirror sync status after deploying. |
| **`${{ forgejo.ref }}` in scheduled workflows** ([PR 13081](https://codeberg.org/forgejo/forgejo/pulls/13081)) | No action: neither scheduled workflow here (`branch-cleanup`, `warrant-bot-drift`) reads `github.ref`. |
| **PR API returns the API URL in the `url` field** ([PR 12643](https://codeberg.org/forgejo/forgejo/pulls/12643)) | Nothing in `mise-tasks/` reads `url` off a pull request (they build `html_url` or their own links), so no change here. Any *new* tooling wanting a browser link must use `html_url`. |
| **`[migrations]` allow/deny host lists now enforced consistently** | No `[migrations]` block in `app.ini.j2`, so upstream defaults apply, unchanged. |

Patch releases 15.0.4 – 15.0.6, passed through on the way, carry no breaking
changes.

What the upgrade buys, beyond staying current: the Actions REST API grew
`/actions/runs/{run_id}/jobs`, `/actions/jobs/{job_id}/logs`,
`/actions/runs/{run_id}/logs`, `/actions/runs/{run_id}/artifacts` and
`/actions/runs/{run_id}/cancel`. The job-log endpoint is the reason this bump
happened when it did: it is the only route that honours an API token, and so
the only way to read a **private** repo's CI log without a browser session.
`mise-tasks/runner-logs` prefers it and falls back to the old web route, which
is anonymous-only. The `forgejo` entry in `service-versions.yaml` records the
dependency so a future downgrade doesn't quietly cost that access.

## v15.0.0 breaking changes (relevant to this instance)

The 14 → 15 major bump (deployed 2026-06-29) carried these breaking changes;
their impact on this deployment:

| Change | Impact here |
|--------|-------------|
| **Public-only access tokens lose private-repo API access** (404 instead of 403 on `/user/repos`, `/orgs/{org}/repos`, …) | Verify mirror-sync / CI PATs are **not** "public only" tokens. Recreate any affected token without the public-only flag. |
| Template generation/deletion APIs now require `write:user` / `write:organization` scope | Affects template/spork automation if it creates repos from templates. |
| **Remember-me cookie renamed** → forces re-login | Cosmetic. To avoid forced logout, pin `[security] COOKIE_REMEMBER_NAME = gitea_incredible` in `app.ini.j2`. Not set here; a one-time re-login is acceptable. |
| Removed `[repository.pull-request] ADD_CO_COMMITTER_TRAILERS` | Not set in `app.ini.j2` — no action. |
| Rootless-container default config path moved to `/var/lib/gitea/custom/conf/app.ini` | N/A — native binary with explicit `-c`. |
| Minimum DB version | No change; SQLite unaffected. |

## Rollback

If the migration fails or the instance is unhealthy, check out the previous tag,
rebuild, restore the DB backup, and redeploy:

```fish
ssh indri 'cd ~/code/3rd/forgejo && git checkout v14.0.3 && mise run build'
ssh indri 'cp ~/forgejo/data/forgejo.db.bak-<date> ~/forgejo/data/forgejo.db'
mise run provision-indri -- --tags forgejo
```

Note that a major-version migration may have altered the schema; restoring the
pre-upgrade DB backup alongside the old binary is the reliable path back.

## Related

- [[forgejo]] - Service reference (build tags, secrets, SSO, monitoring)
- [[manage-forgejo-mirrors]] - Mirror operations (the build source)
- [[review-services]] - Periodic version-freshness review
