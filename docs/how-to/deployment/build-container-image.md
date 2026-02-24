---
title: Build Container Image
modified: 2026-02-24
last-reviewed: 2026-02-15
tags:
  - how-to
  - containers
  - ci
---

# Build a Container Image

How to create a custom container image in BlumeOps, build it locally, and release it to the [[zot]] registry via the Forgejo CI pipeline.

## Prerequisites

- [Dagger CLI](https://docs.dagger.io/install) installed locally (for Dockerfile builds)
- A `Dockerfile` and/or `default.nix` for the service

## 1. Create the container directory

Add build files under `containers/<name>/`:

```
containers/<name>/
├── Dockerfile      (built by Dagger on the k8s runner)
├── default.nix     (built by nix-build on the ringtail runner)
└── (optional scripts, configs)
```

A container can have one or both build files. The directory name becomes the image name: `registry.ops.eblu.me/blumeops/<name>`.

## 2. Build locally

**Dockerfile** — test with Dagger:

```bash
dagger call build --src=. --container-name=<name>
```

**Nix** — test with Dagger (no local nix required):

```bash
dagger call build-nix --src=. --container-name=<name> export --path=./<name>.tar.gz
```

Or with nix-build directly (requires nix, e.g. on [[ringtail]]):

```bash
nix-build containers/<name>/default.nix -o result
```

## 3. Release

Container builds trigger automatically when changes to `containers/<name>/` are merged to `main`. Both workflows fire and each skips if the relevant build file is absent.

To trigger a manual build (e.g. from a branch or to rebuild at a specific commit):

```bash
mise run container-build-and-release <name>
mise run container-build-and-release <name> --ref <commit-sha>
```

Use `--dry-run` to preview without dispatching.

| Build file | Workflow | Runner | Registry tag |
|------------|----------|--------|--------------|
| `Dockerfile` | `build-container.yaml` | `k8s` (indri) | `:vX.Y.Z-<sha>` |
| `default.nix` | `build-container-nix.yaml` | `nix-container-builder` ([[ringtail]]) | `:vX.Y.Z-<sha>-nix` |

The version (`X.Y.Z`) is extracted from `ARG CONTAINER_APP_VERSION=` in the Dockerfile or `version = "..."` in `default.nix`. The SHA is the short (7-char) commit hash.

Check available images and tags with:

```bash
mise run container-list
```

## 4. Update k8s manifests

Change the image reference in `argocd/manifests/<service>/deployment.yaml`:

```yaml
image: registry.ops.eblu.me/blumeops/<name>:vX.Y.Z-abc1234
```

Then deploy per [[deploy-k8s-service]].

### Squash-merge and container tags

Container image tags include the git commit SHA they were built from (e.g. `v3.9.1-74029e1`). When a PR is squash-merged, the original branch commits are replaced by a single new commit on main — the SHA in the image tag no longer exists on main. After branch cleanup (30 days), the SHA becomes unreachable and the container loses source traceability.

**The rule:** Production manifests must reference images built from a commit on main. After merging a PR that changed `containers/<name>/`:

1. The merge to main automatically triggers a rebuild (the `build-container.yaml` / `build-container-nix.yaml` workflows fire on pushes to `main` that touch `containers/**`)
2. Wait for the workflow to complete — check at `https://forge.ops.eblu.me/eblume/blumeops/actions`
3. Find the new main-SHA tag:
   ```bash
   mise run container-list <name>
   ```
   Tags marked `[main]` were built from a commit on main; tags marked `[branch]` are from PR branches
4. Commit a C0 follow-up updating the manifest to use the `[main]` tag:
   ```yaml
   image: registry.ops.eblu.me/blumeops/<name>:vX.Y.Z-<main-sha>
   ```

This follow-up C0 is expected and routine — it's the cost of squash-merge + SHA-tagged containers.

## Common Patterns

Existing containers demonstrate several build approaches:

| Pattern | Example | Notes |
|---------|---------|-------|
| Alpine package install | [[#transmission]] | Simplest — install from apk |
| Go from source | [[#miniflux]] | Clone upstream, `go build` |
| Multi-stage with Node + Go | [[#navidrome]] | Separate UI and backend build stages |
| Multi-stage Elixir | [[#teslamate]] | Elixir release with Node assets |
| Runtime tarball download | [[#kiwix-serve]] | Download pre-built binary with arch detection |
| Nix `dockerTools` | [[#nettest-nix]] | `buildLayeredImage` with nixpkgs tools |

### transmission

`containers/transmission/Dockerfile` — Installs transmission-daemon directly from Alpine packages. Good starting point for services available in apk.

### miniflux

`containers/miniflux/Dockerfile` — Two-stage Go build. Clones upstream at a pinned version tag, runs `make`, copies the binary into a minimal Alpine runtime.

### navidrome

`containers/navidrome/Dockerfile` — Three-stage build with separate Node.js UI compilation, Go backend build with CGO (taglib), and a minimal Alpine runtime with ffmpeg.

### teslamate

`containers/teslamate/Dockerfile` — Two-stage Elixir build with Node.js asset compilation. Uses Debian-based images due to Elixir/OTP dependencies.

### kiwix-serve

`containers/kiwix-serve/Dockerfile` — Downloads a pre-built binary from upstream, with architecture detection for cross-platform support.

### nettest (nix)

`containers/nettest/default.nix` — Uses `dockerTools.buildLayeredImage` with `buildEnv` to merge nixpkgs tools (curl, jq, dnsutils, bash). Runs alongside the existing Dockerfile; the nix variant is tagged `:version-nix` in the registry.

## Related

- [[deploy-k8s-service]] — Deploying the service that uses the image
- [[create-release-artifact-workflow]] — Alternative: release non-container artifacts
- [[dagger]] — Dagger CI reference
