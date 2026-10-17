---
title: Update Documentation
modified: 2026-10-17
last-reviewed: 2026-10-17
tags:
  - how-to
  - documentation
  - ci-cd
---

# Update Documentation

How to publish documentation changes to https://docs.eblu.me.

## Releasing docs

Documentation ships with BlumeOps releases (the release-PR model,
[eblume/blumeops#1628](https://forge.ops.eblu.me/eblume/blumeops/issues/1628)). To
ship docs changes:

1. Prepare the cut with the shared release kit's `cut-release` (eblume/release-kit
   `docs/how-to/cut-a-release.md`): it builds the towncrier section from
   `docs/changelog.d/` fragments (fragments consumed), places a blurb under the
   section heading for minor/major releases, rotates older minor series verbatim
   into `docs/changelog/archive/`, and bumps the root `version` file and the indri
   `docs_version` pin (the repo hook) — review, commit, and open it as a
   `release vX.Y.Z` PR.
2. A human merges. On push to main, `release.yaml` detects the version change,
   builds the docs tarball, and tags + publishes the Forgejo release with the
   CHANGELOG section as its body.
3. Deploy: `mise run provision-indri -- --tags docs` from gilbert, then purge the
   [[flyio-proxy]] nginx cache (`fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`)
   so the new docs are served immediately.

Direct workflow link: https://forge.ops.eblu.me/eblume/blumeops/actions?workflow=release.yaml

## What the Workflow Does

The `release` workflow (`.forgejo/workflows/release.yaml`) fires on every push to
main:

1. **`detect`** (on the unprivileged `indri-build` runner) — verifies the forge
   server URL, compares the root `version` file against the push's before-commit,
   and requires a matching `## [vX.Y.Z]` section in `CHANGELOG.md`; a push that is
   not a release exits clean
2. **`publish`** (on `indri-build`) — builds the docs tarball with
   `mise run docs-build-tarball` (Quartz build in a node:22-slim container via
   colima) into `release-assets/`, then tags and creates the Forgejo release via
   the shared kit's `publish-release` action (`eblume/release-kit@v0.1.1`),
   attaching the tarball

The changelog is cut in the release PR itself (towncrier runs there, not in CI),
so CI never writes to `CHANGELOG.md` and never pushes `main`.

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

Fragments are collected into `CHANGELOG.md` (at repo root) by `cut-release` when the release PR is cut.

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

- **Runner**: launchd services on indri (the `indri` user LaunchAgent; the `indri-build` LaunchDaemon plus its colima VM); the main runner's LaunchAgent, `config.yaml` and the cache maintenance agents are generation-owned (the [[indri]] flake, eblume/blumeops#1528), the `indri-build` runner's config/colima profile stay in the `forgejo_runner` ansible role (no Kubernetes, no job container)
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

**Release push fails in `detect`:**
- The `version` file must have changed vs the push's parent commit
- `CHANGELOG.md` must carry a matching `## [vX.Y.Z]` section (cut-release produces both)

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
