---
title: Upgrade Dagger
modified: 2026-06-18
last-reviewed: 2026-06-18
tags:
  - how-to
  - dagger
  - ci-cd
---

# Upgrade Dagger

How to upgrade the Dagger engine and CLI across BlumeOps. The ordering matters —
the Dagger CLI refuses to run a module whose `engineVersion` is newer than the
CLI, so the CI runner's CLI must be upgraded *before* the new `engineVersion`
reaches CI.

## Where Dagger is pinned

Dagger plays a small CI role since [[retire-minikube]] phase 6: container images
are nix-built (no Dagger), and the only remaining `dagger call` is `build-docs`
in the `Build BlumeOps` workflow. The CI runner is host-mode on [[indri]]
([[configure-launchd-runner]]) — jobs run directly with indri's mise toolchain,
so the runner's Dagger CLI is just a mise pin, not a container image. The engine
runs as a container inside indri's right-sized Docker Desktop (2cpu/4GiB).

The version is pinned in four places that must agree:

| File | What | Role |
|------|------|------|
| `mise.toml` | `dagger` tool version | local dev CLI |
| `ansible/roles/forgejo_runner/defaults/main.yml` | `dagger@X` in `forgejo_runner_host_tools` | CI runner CLI (mise global on indri) |
| `dagger.json` | `engineVersion` | the engine (container in Docker Desktop) |
| `docs/reference/tools/dagger.md` | version references | docs |

`uv.lock` also tracks the Dagger Python SDK and is regenerated automatically.

## Procedure

1. Bump `mise.toml`:
   ```toml
   dagger = "<new-version>"
   ```
   Run `mise install` to get the new CLI locally.

2. Bump `dagger.json`:
   ```json
   "engineVersion": "v<new-version>"
   ```

3. Regenerate the SDK lock — run any `dagger call` (e.g. `dagger functions`).
   This updates `uv.lock` if the SDK dependencies changed.

4. Bump the CI runner's CLI pin in
   `ansible/roles/forgejo_runner/defaults/main.yml`:
   ```yaml
   forgejo_runner_host_tools:
     - dagger@<new-version>
   ```

5. **Provision the runner host first** — before the `engineVersion` bump reaches
   CI:
   ```fish
   mise run provision-indri -- --tags forgejo_runner
   ```
   This runs `mise use --global dagger@<new-version>` on indri and restarts the
   runner LaunchAgent (via the role's `Restart forgejo-runner` handler), so the
   host-mode runner's CLI is new enough for the bumped engine.

6. Update `docs/reference/tools/dagger.md` — bump the version in the Quick
   Reference table and any body references.

7. Commit and push (this is a C1 — open a PR). Once merged, the next CI run uses
   the new `engineVersion` against the already-upgraded host CLI.

8. Test CI — manual-dispatch `Build BlumeOps` and confirm the `build-docs` step
   succeeds.

## Why the order matters

The Dagger CLI refuses to run a module whose `engineVersion` is newer than the
CLI. If the `engineVersion` bump lands in CI before the runner's CLI is
upgraded:

1. CI checks out the new commit (new `engineVersion` in `dagger.json`)
2. The host-mode runner still has the old Dagger CLI on its mise toolchain
3. `dagger call build-docs` exits with a version-mismatch error

Provisioning the runner host (step 5) installs the new CLI on indri *before* the
bump reaches CI, so the CLI is always ≥ the engine version. There is no
container to rebuild — phase 6 retired the `runner-job-image`, so the
chicken-and-egg of the old k8s-runner flow is gone.

## Changelog

Add a changelog fragment (branch name for a C1):
`docs/changelog.d/<branch>.<type>.md`. Use type `infra` for routine upgrades;
include both the old and new versions in the description.

## Related

- [[dagger]] — Dagger reference card
- [[configure-launchd-runner]] — the host-mode CI runner that provides the Dagger CLI
- [[build-container-image]] — How container builds work (nix-only)
- [[update-tooling-dependencies]] — General tooling update procedure
