---
title: Build Container Image
modified: 2026-02-15
last-reviewed: 2026-02-15
tags:
  - how-to
  - containers
  - ci
---

# Build a Container Image

How to create a custom container image in BlumeOps, build it locally, and release it to the [[zot]] registry via the Forgejo CI pipeline.

## Prerequisites

- [Dagger CLI](https://docs.dagger.io/install) installed locally
- A Dockerfile for the service you want to build

## 1. Create the container directory

Add a `Dockerfile` (and any supporting files) under `containers/<name>/`:

```
containers/<name>/
├── Dockerfile
└── (optional scripts, configs)
```

The directory name becomes the image name: `registry.ops.eblu.me/blumeops/<name>`.

## 2. Build locally

Test your image with Dagger:

```bash
dagger call build --src=. --container-name=<name>
```

This builds `containers/<name>/Dockerfile` using the Dagger `docker_build()` function. Fix any build errors before proceeding.

## 3. Release

Once the image builds cleanly, create a tagged release:

```bash
mise run container-tag-and-release <name> v1.0.0
```

This creates a git tag `<name>-v1.0.0` and pushes it. The `build-container` Forgejo workflow triggers on the tag, builds the image via Dagger, and publishes it to the registry as `registry.ops.eblu.me/blumeops/<name>:v1.0.0`.

Check available images and tags with:

```bash
mise run container-list
```

## 4. Update k8s manifests

Change the image reference in `argocd/manifests/<service>/deployment.yaml`:

```yaml
image: registry.ops.eblu.me/blumeops/<name>:v1.0.0
```

Then deploy per [[deploy-k8s-service]].

## Common Patterns

Existing containers demonstrate several build approaches:

| Pattern | Example | Notes |
|---------|---------|-------|
| Alpine package install | [[#transmission]] | Simplest — install from apk |
| Go from source | [[#miniflux]] | Clone upstream, `go build` |
| Multi-stage with Node + Go | [[#navidrome]] | Separate UI and backend build stages |
| Multi-stage Elixir | [[#teslamate]] | Elixir release with Node assets |
| Runtime tarball download | [[#kiwix-serve]] | Download pre-built binary with arch detection |

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

## Related

- [[deploy-k8s-service]] — Deploying the service that uses the image
- [[create-release-artifact-workflow]] — Alternative: release non-container artifacts
- [[dagger]] — Dagger CI reference
