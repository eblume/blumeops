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
- For local builds: `nix` (e.g. on [[ringtail]]) or a `nixos/nix` container (no local nix required)

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

**With nix-build directly** (requires nix, e.g. on [[ringtail]]):

```bash
nix-build containers/<name>/default.nix -o result
```

**In a `nixos/nix` container** (no local nix required, e.g. on a macOS dev box):

```bash
docker run --rm -v "$PWD":/workspace -w /workspace nixos/nix:2.34.4 nix-build containers/<name>/default.nix -o result
```

Either produces a docker-archive tarball you can `docker load` or push with `skopeo`.

## 3. Release

Merge is the release. A push to main touching `containers/<name>/` runs
`build-container.yaml`: the `detect` job (on the `indri` runner,
[[forgejo-runner]]) diffs the push against the previous head to find the
changed containers, and the `build-nix` job (on the `nix-container-builder`
runner, [[ringtail]]) builds `default.nix` with `nix-build` and pushes
`registry.ops.eblu.me/blumeops/<name>:vX.Y.Z-<sha>-nix` to [[zot]]. There is no
dispatch and no warrant — the retired `build-container` request path and its
warrant entry are gone ([[warrant-approval-gated-runs]]).

Container PRs get the build as a check on the same path (never the registry
push — fork runs carry no secrets), so hash-TOFU rounds happen against the PR
itself: the workflow comments the failure on the PR with the relevant
`specified:`/`got:` lines when a hash is wrong, and a green check is the
pre-merge gate. After the PR merges, the push run builds the *merge commit*,
so the tag's `<sha>` is that commit's short hash.

Verify a run with `runner-logs`:

```bash
mise run runner-logs                    # find the new run number
mise run runner-logs <run#>             # see jobs and their status
mise run runner-logs <run#> -j <N>      # fetch full logs (e.g. on failure)
```

| Build file | Workflow | Runner | Registry tag |
|------------|----------|--------|--------------|
| `default.nix` | `build-container.yaml` | `nix-container-builder` ([[ringtail]]) | `:vX.Y.Z-<sha>-nix` |

The version (`X.Y.Z`) is extracted from `version = "..."` in `default.nix`; the
SHA is the short (7-char) hash of the commit built (the merge commit for push
runs). Check available images and tags with:

```bash
mise run container-list
```

## 4. Update k8s manifests

You don't point the manifest yourself for a container bump anymore. Once the
merge-time build pushes the tag, the horkos release publisher opens the
kustomization pin PR that updates `newTag` in
`argocd/manifests/<service>/kustomization.yaml` (images are tagged `:kustomized`
in `deployment.yaml` and rewritten by kustomize):

```yaml
images:
  - name: registry.ops.eblu.me/blumeops/<name>
    newTag: vX.Y.Z-abc1234-nix
```

Merge the pin PR and the app is deployed: for an auto-syncing application,
merging *is* the deploy; there is no step after it. The four manual
applications are the exception ([[argocd#Sync Policy]]);
[[deploy-k8s-service]] covers standing a service up for the first time.

### Container tags and merge strategy

Container image tags include the git commit SHA they were built from (e.g. `v3.9.1-74029e1-nix`). The rule that matters is unchanged: **production manifests must reference an image whose commit is reachable from main.** What changed is that the build now happens *after* the merge, so the rule is satisfied by construction.

The tag's SHA comes from the merge commit itself: the push run builds `GITHUB_SHA` of the push event, which is the merge commit on main. A tag pushed by the workflow is therefore a main commit by definition — `mise run container-list`'s `[main]`/`[branch]` annotation never has to decide, and there are no branch-built tags on the registry anymore.

So the flow is:

1. Open a PR touching `containers/<name>/`. The PR check builds it (TOFU rounds read from the PR comment); fix hashes until it's green
2. Merge. The push run builds the merge commit and pushes the `vX.Y.Z-<7sha>-nix` tag
3. Merge the kustomization pin PR horkos opens with that tag. The app syncs itself (see [[argocd#Sync Policy]])

> **Historical note.** The older flows needed manual care: pre-merge builds had to come from the *final* branch head (a later push touching `containers/` orphaned the image), and before that, a post-merge rebuild plus a second commit re-pointed the manifest because squash-merge replaced the branch commits and orphaned the SHA in the tag. Both dances are gone — the merge-time build is the release, and horkos pins the manifest. Squash-merge was disabled on canonical as a corollary of invariant 2 in [[warrant-approval-gated-runs]]: approvals bind to immutable SHAs, and squashing rewrote every approved SHA.

## Nixpkgs pin

Container builds resolve `<nixpkgs>` from a rev pin in the repo —
`containers/flake.nix` + `containers/flake.lock` — not from the build host's
floating flake registry. A nixpkgs upgrade is therefore a reviewable blumeops
change: bump the pin, review the `flake.lock` diff, and the build check leg of
the workflow proves the containers still build against it. (Same spirit as the
`nixpkgs-services` pin in the ringtail flake.)

To upgrade, from the repo root:

```sh
cd containers
nix flake update nixpkgs
```

then open a PR with the resulting `containers/flake.lock` diff. Updates are
deliberate, per-PR only — there is no scheduled updater. Containers that
self-pin a nixpkgs rev via `fetchTarball` are unaffected by the shared pin.

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
