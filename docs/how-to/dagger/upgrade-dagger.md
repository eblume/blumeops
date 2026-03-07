---
title: Upgrade Dagger
modified: 2026-03-06
last-reviewed: 2026-03-06
tags:
  - how-to
  - dagger
  - ci-cd
---

# Upgrade Dagger

How to upgrade the Dagger engine and CLI across all components in BlumeOps. The ordering matters — upgrading in the wrong sequence creates a chicken-and-egg problem where CI can't build its own replacement.

## Overview

Dagger versions are pinned in multiple places. The runner job image (which executes CI workflows) contains the Dagger CLI, and the module's `dagger.json` declares the engine version. These must match — if the CLI is older than the engine version, Dagger refuses to run.

**Key insight:** Upgrade the runner container *first* (with the new CLI but the old engine version), deploy it, and *then* bump the engine version. This avoids needing a local build to break the cycle.

## Files to update

| File | What | Phase |
|------|------|-------|
| `containers/runner-job-image/Dockerfile` | `CONTAINER_APP_VERSION` (CLI version) | 1 |
| `service-versions.yaml` | `runner-job-image` version and `last-reviewed` | 1 |
| `mise.toml` | `dagger` tool version | 2 |
| `dagger.json` | `engineVersion` | 2 |
| `.dagger/uv.lock` | SDK dependency lock (regenerated automatically) | 2 |
| `docs/reference/tools/dagger.md` | Version references in documentation | 2 |
| `argocd/manifests/forgejo-runner/deployment.yaml` | `RUNNER_LABELS` image tag | 2 |

## Procedure

### Phase 1: Upgrade the runner job image

The runner job image contains the Dagger CLI binary. Upgrading it first means the current CI (still on the old engine version) can build and publish the new image normally.

1. Update `containers/runner-job-image/Dockerfile`:
   ```dockerfile
   ARG CONTAINER_APP_VERSION=<new-version>
   ```

2. Update `service-versions.yaml` — bump `current-version` and `last-reviewed` for `runner-job-image`.

3. Commit and push to main. The `Build Container` workflow triggers automatically (it watches `containers/**`), building and publishing the new runner-job-image with the updated Dagger CLI.

4. Verify the build succeeds — check the workflow run on Forgejo. Note the image tag from the build output (format: `v<version>-<sha>`).

### Phase 2: Upgrade the module and deploy the new runner

Once the Phase 1 build completes, upgrade the module engine version and deploy the new runner in a single commit. None of these paths trigger CI workflows automatically, so there is no race condition.

1. Update `mise.toml`:
   ```toml
   dagger = "<new-version>"
   ```

2. Run `mise install` to get the new CLI locally.

3. Update `dagger.json`:
   ```json
   "engineVersion": "v<new-version>"
   ```

4. Regenerate the SDK lock file — run any `dagger call` command (e.g., `dagger call --help` or `dagger functions`). This updates `.dagger/uv.lock` if SDK dependencies changed.

5. Update `docs/reference/tools/dagger.md` — bump the version in the Quick Reference table and any version references in the body text.

6. Update `argocd/manifests/forgejo-runner/deployment.yaml` — set the `RUNNER_LABELS` value to use the new image tag from Phase 1:
   ```yaml
   value: "k8s:docker://registry.ops.eblu.me/blumeops/runner-job-image:<tag>"
   ```

7. Commit and push to main.

8. Sync the forgejo-runner app:
   ```fish
   argocd app sync forgejo-runner
   ```

9. Verify the runner is healthy:
   ```fish
   argocd app get forgejo-runner
   ```

10. Test CI by triggering a workflow (e.g., manual dispatch of `Build BlumeOps`).

## Why the order matters

The Dagger CLI refuses to run a module whose `engineVersion` is newer than the CLI version. If you upgrade `dagger.json` first:

1. CI tries to run `dagger call` with the old CLI
2. The module declares a newer engine version
3. Dagger exits with a version mismatch error
4. The `Build Container` workflow can't run — so you can't build the new runner image via CI
5. You're stuck: the runner can't build its own replacement

By upgrading the CLI in the runner image first (Phase 1), the current engine version (old) still works fine with the newer CLI. Phase 2 combines the engine version bump with the runner deployment in a single commit — this is safe because none of the changed paths (`dagger.json`, `mise.toml`, `argocd/manifests/forgejo-runner/`) trigger CI workflows automatically. Just sync the forgejo-runner app before triggering any workflows.

## Changelog

Add a changelog fragment: `docs/changelog.d/+upgrade-dagger-<version>.<type>.md`

Use type `infra` for routine upgrades. Include both the old and new versions in the description.

## Related

- [[dagger]] — Dagger reference card
- [[build-container-image]] — How container builds work
- [[update-tooling-dependencies]] — General tooling update procedure
- [[forgejo]] — CI/CD platform
