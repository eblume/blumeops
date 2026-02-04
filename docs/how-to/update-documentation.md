---
title: update-documentation
tags:
  - how-to
  - documentation
  - ci-cd
---

# Update Documentation

How to publish documentation changes to https://docs.ops.eblu.me.

## Quick Release

After merging documentation changes to main:

1. Go to **Actions** > **Build BlumeOps** > **Run workflow**
2. Select version bump type (patch/minor/major) or enter a specific version
3. The workflow builds, releases, and deploys automatically

Direct link: https://forge.ops.eblu.me/eblume/blumeops/actions?workflow=build-blumeops.yaml

## What the Workflow Does

The `build-blumeops` workflow (`.forgejo/workflows/build-blumeops.yaml`):

1. **Resolves version** - Uses input or auto-increments from latest release
2. **Builds changelog** - Runs towncrier to collect changelog fragments
3. **Builds docs** - Clones Quartz, builds static site from `docs/`
4. **Creates release** - Uploads `docs-<version>.tar.gz` to Forgejo releases
5. **Updates deployment** - Edits `argocd/manifests/docs/deployment.yaml` with new URL
6. **Commits changes** - Pushes changelog and deployment updates to main
7. **Deploys** - Syncs the `docs` ArgoCD app

## Changelog Fragments (Towncrier)

When making changes, add a changelog fragment to `docs/changelog.d/`:

```bash
# Format: <identifier>.<type>.md
# Types: feature, bugfix, infra, doc, misc

# Using branch name (preferred)
echo "Add new feature X" > docs/changelog.d/my-feature.feature.md

# Orphan fragment (when no branch fits)
echo "Fix bug Y" > docs/changelog.d/+fix-bug.bugfix.md
```

Fragments are automatically collected into `CHANGELOG.md` (at repo root) during release.

**Fragment types:**
| Type | Directory | Description |
|------|-----------|-------------|
| `feature` | `feature/` | New features |
| `bugfix` | `bugfix/` | Bug fixes |
| `infra` | `infra/` | Infrastructure changes |
| `doc` | `doc/` | Documentation updates |
| `misc` | `misc/` | Other changes |

## Runner Environment

The workflow runs on the `k8s` label, which uses the [[forgejo]]-runner in Kubernetes:

- **Runner deployment**: `argocd/manifests/forgejo-runner/`
- **Job image**: `registry.ops.eblu.me/blumeops/forgejo-runner:latest`
- **Includes**: Node.js 24, npm, git, jq, Docker CLI, uv/uvx, argocd CLI

The job image is built from `containers/forgejo-runner/Dockerfile`.

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
# Clone Quartz
git clone --depth 1 https://github.com/jackyzha0/quartz.git /tmp/quartz
cd /tmp/quartz

# Install dependencies
npm ci

# Copy config and content
cp /path/to/blumeops/docs/quartz.config.ts .
cp /path/to/blumeops/docs/quartz.layout.ts .
rm -rf content
cp -r /path/to/blumeops/docs content

# Build
npx quartz build

# Serve locally
npx quartz build --serve
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
- [[forgejo]] - Git forge and CI/CD
- [[argocd]] - GitOps deployment
