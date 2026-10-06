---
title: Update Documentation
modified: 2026-09-05
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
3. The workflow builds the docs and creates the release; deploying the new
   version is a manual step (see below)

Direct link: https://forge.ops.eblu.me/eblume/blumeops/actions?workflow=build-blumeops.yaml

## What the Workflow Does

The `build-blumeops` workflow (`.forgejo/workflows/build-blumeops.yaml`) splits across three jobs:

1. **`version`** (on the unprivileged `indri-build` runner) — Resolves the version: uses the input or auto-increments from the latest release
2. **`docs-build`** (on the unprivileged `indri-build` runner) — Runs towncrier to update `CHANGELOG.md`, then builds the docs with `mise run docs-build-tarball` (Quartz build in a node:22-slim container via colima); hands the tarball to the release job as a same-run artifact
3. **`release`** (on `indri`) — Re-runs towncrier for the commit, downloads the tarball, creates the Forgejo release (`docs-<version>.tar.gz`), bumps `docs_version`, commits

The workflow ends at the release. Deploying is a manual step (docs are served
natively by Caddy on indri since [[retire-minikube]] — no ArgoCD app): bump
`docs_version` in `ansible/roles/docs/defaults/main.yml`, then
`mise run provision-indri -- --tags docs`, and purge the [[flyio-proxy]] nginx
cache (`fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`)
so the new docs are served immediately.

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

The workflow's jobs split across the two launchd [[forgejo]]-runners on [[indri]]
([[configure-launchd-runner]]) — the `version` and `docs-build` jobs on the
unprivileged `indri-build` runner (colima container engine), the `release` job
on the privileged `indri` host-mode runner because it holds the op token and
the main-push PAT:

- **Runner**: launchd services on indri (the `indri` user LaunchAgent; the `indri-build` LaunchDaemon plus its colima VM), managed by the `forgejo_runner` ansible role (no Kubernetes, no job container)
- **Toolchain**: the docs job uses indri-build's mise toolchain (Node.js, uv/Python, …); the release job runs with indri's
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
