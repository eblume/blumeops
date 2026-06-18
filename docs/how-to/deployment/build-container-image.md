---
title: Build Container Image
modified: 2026-06-17
last-reviewed: 2026-06-17
tags:
  - how-to
  - containers
  - ci
---

# Build a Container Image

How to create a custom container image in BlumeOps, build it locally, and release it to the [[zot]] registry via the Forgejo CI pipeline.

All BlumeOps containers are built from a `default.nix` with `nix-build` and
packaged with `dockerTools`. (Until [[retire-minikube]] in 2026-06, containers
could also be built from a `Dockerfile` or a native `container.py` Dagger
pipeline routed to an arm64 k8s runner; both paths were retired with the
minikube cluster.)

## Prerequisites

- A `containers/<name>/default.nix` for the service
- For local builds: either the [Dagger CLI](https://docs.dagger.io/install) (no local nix required) or `nix` (e.g. on [[ringtail]])

## 1. Create the container directory

Add build files under `containers/<name>/`:

```
containers/<name>/
├── default.nix     (built by nix-build on the ringtail runner)
└── (optional scripts, configs)
```

The directory name becomes the image name: `registry.ops.eblu.me/blumeops/<name>`.

The `default.nix` must declare a `version = "..."` (used to tag the image) and
evaluate to a docker-archive image — in practice
`pkgs.dockerTools.buildLayeredImage`. Common shapes:

| Pattern | Example | Notes |
|---------|---------|-------|
| Lift-and-shift from nixpkgs | [[#navidrome]], [[#miniflux]] | `app = pkgs.<name>` with an `assert app.version == version` guard |
| Build from source | [[#ntfy]] | `buildGoModule` / `buildNpmPackage` against a pinned `fetchgit`/`fetchFromGitHub` |
| Upstream prebuilt binary | [[#kiwix-serve]] | `fetchurl` a release tarball, pinned by hash |
| Multi-component | [[#authentik]] | `writeShellScript` entrypoints + several store paths in `contents` |

## 2. Build locally

**With Dagger** (no local nix required):

```bash
dagger call build-nix --src=. --container-name=<name> export --path=./<name>.tar.gz
```

**With nix-build directly** (requires nix, e.g. on [[ringtail]]):

```bash
nix-build containers/<name>/default.nix -o result
```

Either produces a docker-archive tarball you can `docker load` or push with `skopeo`.

## 3. Release

Container builds are triggered manually. Shared Dagger helpers (`src/blumeops/`)
affect docs and flake-lock pipelines, so path-based auto-triggers are unreliable.

To trigger a build:

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
| `default.nix` | `build-container.yaml` | `nix-container-builder` ([[ringtail]]) | `:vX.Y.Z-<sha>-nix` |

The version (`X.Y.Z`) is extracted from `version = "..."` in `default.nix`. The SHA is the short (7-char) commit hash.

Check available images and tags with:

```bash
mise run container-list
```

## 4. Update k8s manifests

Update the `newTag` in `argocd/manifests/<service>/kustomization.yaml` (images
are tagged `:kustomized` in `deployment.yaml` and rewritten by kustomize):

```yaml
images:
  - name: registry.ops.eblu.me/blumeops/<name>
    newTag: vX.Y.Z-abc1234-nix
```

Then deploy per [[deploy-k8s-service]].

### Squash-merge and container tags

Container image tags include the git commit SHA they were built from (e.g. `v3.9.1-74029e1-nix`). When a PR is squash-merged, the original branch commits are replaced by a single new commit on main — the SHA in the image tag no longer exists on main. After branch cleanup (30 days), the SHA becomes unreachable and the container loses source traceability.

**The rule:** Production manifests must reference images built from a commit on main. After merging a PR that changed `containers/<name>/`:

1. Trigger a rebuild: `mise run container-build-and-release <name>`
2. Wait for the workflow to complete — verify with `mise run runner-logs` (find the run, check status)
3. Find the new main-SHA tag:
   ```bash
   mise run container-list <name>
   ```
   Tags marked `[main]` were built from a commit on main; tags marked `[branch]` are from PR branches
4. Commit a C0 follow-up updating the `newTag` to the `[main]` tag

This follow-up C0 is expected and routine — it's the cost of squash-merge + SHA-tagged containers.

## Reference Examples

Existing `default.nix` files demonstrate the common patterns:

### navidrome

`containers/navidrome/default.nix` — Lift-and-shift: `app = pkgs.navidrome` with an `assert app.version == version` guard, wrapped in `dockerTools.buildLayeredImage` with ffmpeg. Use this when the upstream package is already in nixpkgs.

### miniflux

`containers/miniflux/default.nix` — Lift-and-shift of `pkgs.miniflux` with the same version-assertion pattern as navidrome. Migrated from a from-source Dockerfile build.

### ntfy

`containers/ntfy/default.nix` — Build from source: `buildNpmPackage` for the UI and `buildGoModule` for the binary, both against a pinned `fetchgit`, packaged with `buildLayeredImage`. Use this when you need to build upstream from a pinned revision.

### kiwix-serve

`containers/kiwix-serve/default.nix` — Downloads an upstream prebuilt binary via `fetchurl` (pinned by hash) and layers it with `dumb-init`/`busybox`. Use this when upstream only ships binaries.

### authentik

`containers/authentik/default.nix` — Multi-component: `writeShellScript` entrypoints plus several store paths in `contents`. Reference for complex images that need more than a single app binary.

## Related

- [[deploy-k8s-service]] — Deploying the service that uses the image
- [[create-release-artifact-workflow]] — Alternative: release non-container artifacts
- [[dagger]] — Dagger CI reference
