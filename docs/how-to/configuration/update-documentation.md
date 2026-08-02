---
title: Update Documentation
modified: 2026-02-19
last-reviewed: 2026-02-19
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
3. The workflow builds, releases, and deploys automatically

Direct link: https://forge.eblu.me/eblume/blumeops/actions?workflow=build-blumeops.yaml

## What the Workflow Does

The `build-blumeops` workflow (`.forgejo/workflows/build-blumeops.yaml`):

1. **Resolves version** — Uses input or auto-increments from latest release
2. **Builds changelog** — Runs towncrier on the runner to update `CHANGELOG.md`
3. **Builds docs** — Calls `dagger call build-docs` (Quartz build in a container)
4. **Creates release** — Uploads `docs-<version>.tar.gz` to Forgejo releases
5. **Updates deployment** — Edits `argocd/manifests/docs/deployment.yaml` with new URL
6. **Commits changes** — Pushes changelog and deployment updates to main
7. **Deploys** — Syncs the `docs` ArgoCD app
8. **Purges cache** — Clears the nginx cache on the [[flyio-proxy]] so the new docs are served immediately

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

The workflow runs on the `indri` label, served since [[retire-minikube]] phase 6
by the host-mode [[forgejo]]-runner on [[indri]] ([[configure-launchd-runner]]):

- **Runner**: native LaunchAgent on indri, managed by the `forgejo_runner` ansible role (no Kubernetes, no job container)
- **Toolchain**: jobs run directly with indri's mise toolchain (Node.js, uv/Python, [[dagger]], …); the `k8s` compat label was dropped once workflows repo-wide moved to `runs-on: indri`
- **Build engine**: the [[dagger]] CLI (mise-pinned in the `forgejo_runner` role) drives the Dagger engine container in indri's Docker Desktop

## Quartz Static Site Generator

[Quartz](https://quartz.jzhao.xyz/) builds the documentation into a static site with:
- Wiki-link support (`[[page]]` syntax)
- Backlinks panel showing what references each page
- Graph view of document connections
- Full-text search

**Configuration files** (in `docs/`):
- `quartz.config.ts` - Site metadata, plugins, theme
- `quartz.layout.ts` - Page layout components

Quartz is cloned fresh during each build (not vendored) to use the latest version.

## Manual Build (Local)

To test docs locally without triggering a release:

```bash
# Build docs tarball (identical to CI)
dagger call build-docs --src=. --version=dev export --path=./docs-dev.tar.gz

# Inspect the output
tar tf docs-dev.tar.gz | head -20

# Debug a Quartz build failure interactively
dagger call --interactive build-docs --src=. --version=dev
```

## Troubleshooting

**Workflow fails on "Resolve version":**
- Check if the version already exists as a release
- Ensure version format is `vX.Y.Z`

**Docs not updating after deploy:**
- Check ArgoCD sync status: `argocd app get docs`
- Verify the pod restarted: `kubectl --context=minikube-indri -n docs get pods`
- Check pod logs for download errors

**Towncrier not finding fragments:**
- Fragments must be in `docs/changelog.d/`
- Must have `.md` extension
- Must match pattern `<name>.<type>.md`

## Related

- [[docs]] - Documentation service reference
- [[dagger]] - Build engine reference
- [[forgejo]] - Git forge and CI/CD
- [[argocd]] - GitOps deployment
