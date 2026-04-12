---
title: Build Container Image
modified: 2026-04-11
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
- A `container.py`, `Dockerfile`, and/or `default.nix` for the service

## 1. Create the container directory

Add build files under `containers/<name>/`:

```
containers/<name>/
├── container.py    (native Dagger pipeline — preferred for new containers)
├── Dockerfile      (legacy — built via docker_build() fallback)
├── default.nix     (built by nix-build on the ringtail runner)
└── (optional scripts, configs)
```

A container can have one or more build files. The directory name becomes the image name: `registry.ops.eblu.me/blumeops/<name>`.

**New containers for indri (k8s runner) should use `container.py`** — native Dagger pipelines surface full build errors per step, while `docker_build()` (used for Dockerfiles) swallows errors. See `containers/navidrome/container.py` for the reference pattern. Existing Dockerfile containers are migrated incrementally during [[review-services|service reviews]].

**Ringtail containers should continue using `default.nix`** — these are built by `nix-build` on the ringtail runner and don't benefit from the Dagger migration.

## 2. Build locally

**Any container** (native `container.py` or legacy Dockerfile) — test with Dagger:

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

After dispatching, verify the workflow succeeded with `runner-logs`:

```bash
mise run runner-logs                    # find the new run number
mise run runner-logs <run#>             # see jobs and their status
mise run runner-logs <run#> -j <N>      # fetch full logs (e.g. on failure)
```

| Build file | Workflow | Runner | Registry tag |
|------------|----------|--------|--------------|
| `container.py` | `build-container.yaml` | `k8s` (indri) | `:vX.Y.Z-<sha>` |
| `Dockerfile` | `build-container.yaml` | `k8s` (indri) | `:vX.Y.Z-<sha>` |
| `default.nix` | `build-container.yaml` | `nix-container-builder` ([[ringtail]]) | `:vX.Y.Z-<sha>-nix` |

The version (`X.Y.Z`) is extracted from `VERSION` in `container.py` (via `dagger call container-version`), `ARG CONTAINER_APP_VERSION=` in Dockerfiles, or `version = "..."` in `default.nix`. The SHA is the short (7-char) commit hash.

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
2. Wait for the workflow to complete — verify with `mise run runner-logs` (find the run, check status)
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
| Native Dagger (Go + Node) | [[#navidrome]] | `container.py` with helper functions — preferred for new containers |
| Alpine package install | [[#transmission]] | Simplest Dockerfile — install from apk |
| Go from source | [[#miniflux]] | Dockerfile: clone upstream, `go build` |
| Multi-stage Elixir | [[#teslamate]] | Dockerfile: Elixir release with Node assets |
| Runtime tarball download | [[#kiwix-serve]] | Dockerfile: download pre-built binary with arch detection |
| Nix `dockerTools` | [[#ntfy-nix]] | `buildLayeredImage` with nix-built app (ringtail runner) |

### navidrome

`containers/navidrome/container.py` — Native Dagger build. Three-stage pipeline using helper functions: `node_build()` for UI, `go_build()` with CGO/taglib/FTS5 for backend, `alpine_runtime()` with ffmpeg. This is the reference pattern for migrating Dockerfile containers to native Dagger builds.

### transmission

`containers/transmission/Dockerfile` — Installs transmission-daemon directly from Alpine packages. Good starting point for services available in apk. (Legacy Dockerfile — migrate to `container.py` during review.)

### miniflux

`containers/miniflux/Dockerfile` — Two-stage Go build. Clones upstream at a pinned version tag, runs `make`, copies the binary into a minimal Alpine runtime. (Legacy Dockerfile — migrate to `container.py` during review.)

### teslamate

`containers/teslamate/Dockerfile` — Two-stage Elixir build with Node.js asset compilation. Uses Debian-based images due to Elixir/OTP dependencies. (Legacy Dockerfile — migrate to `container.py` during review.)

### kiwix-serve

`containers/kiwix-serve/Dockerfile` — Downloads a pre-built binary from upstream, with architecture detection for cross-platform support. (Legacy Dockerfile — migrate to `container.py` during review.)

### ntfy (nix)

`containers/ntfy/default.nix` — Builds ntfy from source using `buildGoModule` and packages it with `dockerTools.buildLayeredImage`. Runs alongside the existing Dockerfile; the nix variant is tagged `:version-nix` in the registry. Nix containers should continue using `default.nix`.

## Related

- [[deploy-k8s-service]] — Deploying the service that uses the image
- [[create-release-artifact-workflow]] — Alternative: release non-container artifacts
- [[dagger]] — Dagger CI reference
