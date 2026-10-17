---
title: Update Documentation
modified: 2026-10-16
last-reviewed: 2026-09-05
tags:
  - how-to
  - documentation
  - ci-cd
---

# Update Documentation

How to publish documentation changes to https://docs.eblu.me.

## Quick Release

After merging documentation changes to main:

1. Go to **Actions** > **Build BlumeOps** > **Run workflow**
2. Select version bump type (patch/minor/major) or enter a specific version
3. The workflow builds the docs; the `release` job hard-fails (releases are
   paused until the release-PR model lands at migration step 9,
   [eblume/blumeops#1628](https://forge.ops.eblu.me/eblume/blumeops/issues/1628)). Deploying
   the last released version is a manual step (see below)

Direct link: https://forge.ops.eblu.me/eblume/blumeops/actions?workflow=build-blumeops.yaml

## What the Workflow Does

The `build-blumeops` workflow (`.forgejo/workflows/build-blumeops.yaml`) splits across three jobs:

1. **`version`** (on the unprivileged `indri-build` runner) — Resolves the version: uses the input or auto-increments from the latest release
2. **`docs-build`** (on the unprivileged `indri-build` runner) — Runs towncrier to update `CHANGELOG.md`, then builds the docs with `mise run docs-build-tarball` (Quartz build in a node:22-slim container via colima); hands the tarball to the release job as a same-run artifact
3. **`release`** (on `indri-build`) — **Paused** ([eblume/blumeops#1628](https://forge.ops.eblu.me/eblume/blumeops/issues/1628)): hard-fails instead of creating the release, until migration step 9 replaces the flow with a release created from the version bump on main

The workflow ends at the release. BlumeOps releases are **paused** until
step 9 of the release-PR model ([eblume/blumeops#1628](https://forge.ops.eblu.me/eblume/blumeops/issues/1628)):
the old release job pushed the changelog and the `docs_version` bump to main
with a PAT, that push is retired, and until step 9 lands there is no
replacement for it. From step 9 on, the `docs_version` bump rides the
release PR and the release is created from the version bump on main.
Deploying is a manual step (docs are served natively by Caddy on indri since
[[retire-minikube]] — no ArgoCD app): once `docs_version` in
`ansible/roles/docs/defaults/main.yml` is at the release tag,
`mise run provision-indri -- --tags docs`, and purge the [[flyio-proxy]] nginx
cache (`fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`)
so the new docs are served immediately. Until the pause lifts, this deploys
the last released docs version — re-running it changes nothing new.

## Changelog Fragments (Towncrier)

When making changes, add a changelog fragment to `docs/changelog.d/`:

```bash
# Format: <identifier>.<type>.md
# Types: feature, bugfix, infra, doc, ai, misc

# Using branch name (preferred)
echo "Add new feature X" > docs/changelog.d/my-feature.feature.md

# Orphan fragment (when no branch fits)
echo "Fix bug Y" > docs/changelog.d/+fix-bug.bugfix.md
```

Fragments are automatically collected into `CHANGELOG.md` (at repo root) during release.

**Fragment types:**
| Type | Description |
|------|-------------|
| `feature` | New features |
| `bugfix` | Bug fixes |
| `infra` | Infrastructure changes |
| `doc` | Documentation updates |
| `ai` | AI assistance changes |
| `misc` | Other changes |

## Runner Environment

All of the workflow's jobs run on the unprivileged launchd [[forgejo]]
`indri-build` runner on [[indri]] (colima container engine)
([[configure-launchd-runner]]):

- **Runner**: launchd services on indri (the `indri` user LaunchAgent; the `indri-build` LaunchDaemon plus its colima VM); the main runner's LaunchAgent, `config.yaml` and the cache maintenance agents are generation-owned (the [[indri]] flake, eblume/blumeops#1528), and the `indri-build` runner's config/colima profile are generation-owned too (eblume/blumeops#1627); no Kubernetes, no job container
- **Toolchain**: all jobs use indri-build's mise toolchain (Node.js, uv/Python, …)
- **Build engine**: the docs build runs a node:22-slim container via the `docs-build-tarball` task in indri-build's colima — not Docker Desktop (no Dagger)

## Quartz Static Site Generator

[Quartz](https://quartz.jzhao.xyz/) builds the documentation into a static site with:
- Wiki-link support (`[[page]]` syntax)
- Backlinks panel showing what references each page
- Graph view of document connections
- Full-text search

**Configuration file** (in `docs/`):
- `quartz.config.yaml` - Site metadata, plugins, theme, and page layout (v5, single file)

Quartz is cloned fresh during each build (not vendored) to use the latest version.

## Manual Build (Local)

To test docs locally without triggering a release:

```bash
# Build docs tarball (identical to CI)
mise run docs-build-tarball ./docs-dev.tar.gz

# Inspect the output
tar tf docs-dev.tar.gz | head -20

# Debug a Quartz build failure interactively: same setup as the task, then stay in
docker run --rm -it -v "$PWD":/workspace:ro node:22-slim sh -c '
  set -e
  apt-get update -qq && apt-get install -y -qq git
  mkdir -p /build && cd /build
  cp -r /workspace/docs . && cp /workspace/CHANGELOG.md docs/
  git clone --depth=1 https://github.com/jackyzha0/quartz.git /tmp/quartz
  cp -r /tmp/quartz/quartz /tmp/quartz/package*.json /tmp/quartz/tsconfig.json /tmp/quartz/quartz.ts /tmp/quartz/.npmrc .
  npm install
  cp docs/quartz.config.yaml .
  npx quartz build -d docs
  echo "Build done — inspect /build/public"
  exec sh
'
```

## Troubleshooting

**Workflow fails on "Resolve version":**
- Check if the version already exists as a release
- Ensure version format is `vX.Y.Z`

**Docs not updating after deploy:**
- Confirm `docs_version` was bumped in `ansible/roles/docs/defaults/main.yml` and the provision ran
- Check the installed version sentinel: `ssh indri 'cat ~/blumeops/docs/.installed-version'`
- If stale content is served publicly, purge the [[flyio-proxy]] cache (see above)

**Towncrier not finding fragments:**
- Fragments must be in `docs/changelog.d/`
- Must have `.md` extension
- Must match pattern `<name>.<type>.md`

## Related

- [[docs]] - Documentation service reference
- [[forgejo]] - Git forge and CI/CD
- [[argocd]] - GitOps deployment
