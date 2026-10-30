---
title: Build a Spork Container
modified: 2026-10-30
last-reviewed: 2026-10-30
tags:
  - how-to
  - containers
  - git
---

# Build a Spork Container

How to build a container image from a [[spork-strategy|sporked]] project with fully-pinned, reproducible inputs.

> **No spork is active.** Kingfisher, the first spork, was retired in `a02e30a8c6d2`. Its `containers/kingfisher/` and `argocd/manifests/kingfisher/` no longer exist. The steps below are the generic procedure; `<project>` stands for the spork's name.

## Why not use the `deploy` branch directly?

The `deploy` branch is force-pushed on every mirror-sync. Building from `deploy` is not reproducible — the same build a week later fetches different code (or fails because the old commit was garbage collected).

Instead, spork containers use Nix to fetch upstream `main` at a pinned SHA and generate patches from feature branches at pinned SHAs. Both upstream and feature commits are on stable branches that are never force-pushed.

## How the Nix build works

The `default.nix` uses `builtins.fetchGit` (eval-time, network access) to fetch two source trees:

1. **Upstream source** at the pinned `upstreamRev` on `main`
2. **Feature branch source** at the pinned `rev` for each feature

Then a sandboxed `diff -ruN` generates a patch from upstream→feature for each feature branch. `buildRustPackage` applies the patches to the upstream source and builds.

This means:
- The upstream rev persists forever (main only fast-forwards)
- Feature revs are on your branches (you control them)
- No dependency on the `deploy` branch
- Fully reproducible given the same revs

## Prerequisites

- Sporked project set up (see [[create-a-spork]])
- Nix build runs on ringtail (`nix-container-builder` runner)

## Get the SHAs

```fish
cd ~/code/3rd/<project>
git fetch origin

# Upstream SHA (main branch)
git rev-parse origin/main
# e.g., 1d37d2983cd4a58c12663dd8df0e79dfe89a5d75

# Feature branch SHAs
git rev-parse origin/feature/upstream/clone-url-base
# e.g., 677c7a5d5fc42b655d38fbf95dc8b814d89ceabb
```

## Update `default.nix`

Edit `containers/<project>/default.nix`:

- `version` — short upstream SHA (for container tag)
- `upstreamRev` — full upstream main SHA
- `features[].rev` — full feature branch SHA

If dependencies changed, update `Cargo.lock` too:

```fish
cd ~/code/3rd/<project>
git checkout origin/main
cargo update
cp Cargo.lock ~/code/personal/blumeops/containers/<project>/Cargo.lock
```

## Build and release

Merge is the release: merging a PR touching `containers/<project>/` runs `build-container.yaml` on ringtail's `nix-container-builder` runner, which builds `default.nix` at the merge commit and pushes `registry.ops.eblu.me/blumeops/<project>:v<version>-<7sha>-nix` to zot. The PR itself got the build as a check first (never the registry push — fork runs carry no secrets), so hash-TOFU rounds and nix errors surface on the PR before merge. No dispatch, no warrant.

## Update the deployment

1. Update `service-versions.yaml` if the upstream SHA changed — in the same container PR
2. The horkos release publisher opens the kustomization pin PR updating `argocd/manifests/<project>/kustomization.yaml` with the new tag — merging it deploys (auto-sync apps deploy themselves on merge; no `argocd app sync` needed)

## Note on `CONTAINER_APP_VERSION`

The `default.nix` includes `version` which maps to `CONTAINER_APP_VERSION` for the `container-version-check` hook. For sporked containers this is a git SHA, not a release version. Don't confuse it with an upstream release number.

## Reproducibility

The upstream rev must be an ancestor of each feature rev. If you bump the upstream rev without rebasing your feature branches, the generated patch will conflict and the build fails — which is the correct behavior.

The invariant: **feature revs are descendants of the upstream rev**. Mirror-sync maintains this automatically. You just need to update the revs in `default.nix` after an upgrade.

## See also

- [[create-a-spork]] — initial spork setup
- [[manage-spork-branches]] — feature branch workflow
- [[spork-strategy]] — why we spork (Kingfisher, the worked example here, has been retired)
