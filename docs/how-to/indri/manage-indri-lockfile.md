---
title: Manage Indri Lockfile
modified: 2026-11-23
last-reviewed: 2026-11-23
tags:
  - how-to
  - indri
  - nix
---

# Manage Indri Lockfile

The indri nix-darwin flake lockfile (`darwin/indri/flake.lock`) is rolled by the
**Indri Flake Update** workflow every **Sunday 05:00 UTC** (also manually
dispatchable). It is the indri counterpart of
[Manage Ringtail Lockfile](../ringtail/manage-lockfile.md), with a reduced
battery: indri has no kernel to compare.

The workflow (`.forgejo/workflows/indri-flake-update.yaml`) updates `nixpkgs`
and `nix-darwin`. `hephaestus` is not updated: its URL carries a fixed `?rev=`
in `darwin/indri/flake.nix`, so a flake update would not move it. Bump that rev
by hand when wanted.

## The scheduled update

1. The zero-credential job `update-and-build` runs on the unprivileged
   `indri-build` runner. It holds no token and blanks `GITHUB_TOKEN` on every
   nix step. It updates the two inputs, records each tracked branch's head,
   builds `.#darwinConfigurations.indri.system`, and runs the check battery.
   Its output is one artifact.
2. The posting job `checks-and-post` runs on `nix-container-builder` and runs no
   nix. It pins the artifact by SHA-256, checks that `main` still carries the
   locked base lock, and pushes `auto-update/indri-flake-<date>` from `main`.
   The diff is exactly the lock plus a changelog fragment. It opens the PR and
   posts the check table against the head SHA.

If the lock did not move, nothing happens. If the battery is red, no PR is
opened and the failure sink files `Workflow failed: indri-flake-update`.

## The check battery

The battery is `nixos/ringtail/flake-lock-check` run with
`--allowed "nixpkgs nix-darwin"`. Checks 1-5 are the ringtail ones; the kernel
check does not apply.

| # | Check | Catches |
|---|-------|---------|
| 1 | **Scope** - only `nixpkgs` and `nix-darwin` moved; every other node is byte-identical. | Unrelated nodes touched, extra inputs. |
| 2 | **Originals** - every root input's `original` is unchanged. | Redirected sources. |
| 3 | **Fast-forward head** - the new rev equals the recorded head of the tracked branch. | Revs that are not the upstream head. |
| 4 | **Fast-forward ancestor** - the old rev is an ancestor of the new one. | Force-reset branches. |
| 5 | **narHash** - the lock's `narHash` matches a fresh fetch. | Fetch divergence. Not a provenance claim. |

## Merging

The workflow opens the PR with the Actions token, which starts no workflows, so
the required checks do not run on it. Close and reopen the PR as myself so
`Indri Flake Check` runs on the same head SHA the table names. Merge when the
table and the checks are green. Merging applies the lock to indri
(`provision-indri` is auto-apply).

## Related

- Caddy plugin bumps are not part of this roll: the plugin list and vendor hash
  live in `darwin/indri/flake.nix` and change by hand.
