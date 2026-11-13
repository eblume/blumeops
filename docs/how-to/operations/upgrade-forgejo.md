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
2. Check `darwin/indri/forgejo.nix` (the rendered `app.ini`) for any settings the release removed or renamed.
3. Confirm the database backend: `grep -iA3 '\[database\]' ~/forgejo/custom/conf/app.ini`.
   The instance uses **SQLite3** (`~/forgejo/data/forgejo.db`), so a backup is a
   file copy.

## Procedure

The pin lives in `darwin/indri/forgejo-pins.yaml` (`forgejo_version`). The
generation owns the LaunchAgent and `app.ini` (`darwin/indri/forgejo.nix`);
the checks slot refuses a host whose binary does not report
the pin. **Order matters**: build the new tag on indri first, then bump the
pin. A bump merged before the build fails its own auto-apply.

Borgmatic already dumps `forgejo.db` (WAL-safe) and the git repositories nightly,
so a recent backup normally exists. For a **major** bump, still take an explicit
same-day snapshot before deploying:

```fish
# 1. Back up the SQLite database (belt and suspenders) while forgejo is up.
ssh indri 'cp ~/forgejo/data/forgejo.db ~/forgejo/data/forgejo.db.bak-(date +%Y%m%d)'

# 2. Build the new tag on indri (no PR yet). Remove any untracked `mise.toml`
#    in the checkout by hand first (a stale one pins go). Do NOT run `make forgejo`:
#    it rebuilds with empty TAGS and strips SQLite support. Use `make build` with
#    the TAGS below.
ssh indri 'cd ~/code/3rd/forgejo && git fetch --tags && git checkout <new-tag>'
ssh indri 'cd ~/code/3rd/forgejo && mise x node@24 -- env TAGS="bindata timetzdata sqlite sqlite_unlock_notify" make build && ln -f gitea forgejo'
ssh indri '~/code/3rd/forgejo/forgejo --version'   # confirm the new tag (replace <new-tag> above)
```

> **Build-to-pin window.** Once step 2 is done, the indri binary reports the new
> tag while `forgejo-pins.yaml` still names the old one, so any unrelated indri
> apply in that window fails the forgejo version check in the checks slot. Keep
> the window short: do step 3 right after step 2.

```fish
# 3. Bump the pin in darwin/indri/forgejo-pins.yaml in a PR:
#      forgejo_version: "v16.0.6"
#    and merge. The apply restarts forgejo; check that
#    /var/log/indri-rebuild/<sha>.status reads 0 (see provision.md).
```

> **Go toolchain (why `go.set_goroot` is off on indri).** mise exports
> `GOROOT` by default (`go.set_goroot`, on), which breaks Go's
> `GOTOOLCHAIN=auto` switching: the auto-switched driver then resolves
> `compile` from the pinned `GOROOT` and dies with `compile: version "goX"
> does not match go tool version "goY"`. The setting and the global go
> baseline now live in the indri flake's mise config
> (`darwin/indri/configuration.nix`; the play's `mise settings set` /
> `mise use --global go@…` tasks are deleted). A plain `make build` now
> works at any tag — Go reads the `go`/`toolchain` lines of go.mod and
> downloads the needed toolchain itself. The flake's go pin is a starting
> point, not a floor to chase.

## Rollback

Do not run a `--tags forgejo` role apply to roll back; the role is retired.
A forgejo flip is rolled back by reverting the retire PR (which restores the
role and its `forgejo_ansible_managed` gate), then the B4 order: `sudo
darwin-rebuild --rollback` first, then `mise run provision-indri -- --tags
forgejo -e forgejo_ansible_managed=true`, then re-apply forward. See
[[provision]] §Forgejo and §Rolling back a service flip.

For a bad upgrade of the binary itself, restore the DB backup alongside the
previous tag's build; a major-version migration may have altered the schema,
so restoring the pre-upgrade DB backup with the old binary is the reliable path
back.

## Post-upgrade verification

```fish
# Version + health
ssh indri '~/code/3rd/forgejo/forgejo --version'
mise run services-check

# Database consistency (recommended after major upgrades)
# -w and -c are required and must precede the subcommand: forgejo derives its
# work path from the binary's own directory, not the shell's, so without them it
# looks for app.ini under ~/code/3rd/forgejo and dies with "Unable to load
# config file for a installed Forgejo instance". Same two flags the LaunchAgent
# passes. Read-only, so it is safe while forgejo is running.
ssh indri '~/code/3rd/forgejo/forgejo -w ~/forgejo -c ~/forgejo/custom/conf/app.ini doctor check --run check-db-consistency'
```

Two warnings are expected and benign on this instance: topics with an empty
repository count, and `action` rows whose user no longer exists. Neither is an
inconsistency the upgrade introduced.

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
| **Repository-based server-side hooks replaced with centralised hooks** ([PR 10397](https://codeberg.org/forgejo/forgejo/pulls/10397)) | The big one. Rewrites hooks in every repository on upgrade. Upstream lists it under ["known problematic versions or upgrade paths"](https://forgejo.org/docs/latest/admin/upgrade/#when-upgrading-from--known-problematic-versions-or-upgrade-paths) — read that section before deploying, and run the `doctor check` above afterwards. Verify a push still triggers CI: a broken hook breaks pushes, not just Actions. |
| **Docker default `REVERSE_PROXY_TRUSTED_PROXIES = *` removed** ([PR 12782](https://codeberg.org/forgejo/forgejo/pulls/12782)) | No-op for the upgrade: `darwin/indri/forgejo.nix` sets it **explicitly** (with `REVERSE_PROXY_LIMIT = 2`), so nothing changes. Worth noting separately that upstream now treats `*` as unsafe — narrowing it to Caddy's address is its own change, not part of this bump. |
| **git mirror HTTP operations no longer follow redirects** ([PR 13129](https://codeberg.org/forgejo/forgejo/pulls/13129)) | Affects the GitHub mirrors ([[manage-forgejo-mirrors]]). Direct `github.com/<owner>/<repo>` URLs don't redirect, but a *renamed* upstream does — a mirror that silently relied on GitHub's rename redirect will start failing. Check mirror sync status after deploying. |
| **`${{ forgejo.ref }}` in scheduled workflows** ([PR 13081](https://codeberg.org/forgejo/forgejo/pulls/13081)) | No action: the one scheduled workflow here (`forge-reconcile`) does not read `github.ref`. |
| **PR API returns the API URL in the `url` field** ([PR 12643](https://codeberg.org/forgejo/forgejo/pulls/12643)) | Nothing in `mise-tasks/` reads `url` off a pull request (they build `html_url` or their own links), so no change here. Any *new* tooling wanting a browser link must use `html_url`. |
| **`[migrations]` allow/deny host lists now enforced consistently** | No `[migrations]` block in `darwin/indri/forgejo.nix`, so upstream defaults apply, unchanged. |

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
| **Remember-me cookie renamed** → forces re-login | Cosmetic. To avoid forced logout, pin `[security] COOKIE_REMEMBER_NAME = gitea_incredible` in `darwin/indri/forgejo.nix`. Not set here; a one-time re-login is acceptable. |
| Removed `[repository.pull-request] ADD_CO_COMMITTER_TRAILERS` | Not set in `darwin/indri/forgejo.nix` — no action. |
| Rootless-container default config path moved to `/var/lib/gitea/custom/conf/app.ini` | N/A — native binary with explicit `-c`. |
| Minimum DB version | No change; SQLite unaffected. |

## Related

- [[forgejo]] - Service reference (build tags, secrets, SSO, monitoring)
- [[manage-forgejo-mirrors]] - Mirror operations (the build source)
- [[review-services]] - Periodic version-freshness review
