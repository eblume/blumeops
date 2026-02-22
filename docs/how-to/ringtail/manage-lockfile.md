---
title: Manage Ringtail Lockfile
modified: 2026-02-22
tags:
  - how-to
  - ringtail
  - nix
---

# Manage Ringtail Lockfile

Two [[dagger]] pipelines manage the ringtail NixOS flake lockfile (`nixos/ringtail/flake.lock`) for different purposes.

## Update All Inputs

To pull the latest versions of all flake inputs (equivalent to `nix flake update`):

```fish
# Update flake.lock
dagger call flake-update --src=. --flake-path=nixos/ringtail \
    export --path=nixos/ringtail/flake.lock

# Commit, push, then deploy
git add nixos/ringtail/flake.lock
git commit -m "Update ringtail flake inputs"
git push
mise run provision-ringtail
```

## Lock New Inputs Only

`mise run provision-ringtail` automatically runs `flake-lock` before deploying. This resolves any newly added inputs without upgrading existing ones (equivalent to `nix flake lock`). If the lockfile changes, the task stages the file and exits — commit, push, and re-run.

This is the right behavior for provisioning: configuration changes that add a new input get locked, but existing inputs stay pinned until explicitly updated.

## Related

- [[ringtail]] — Host reference
- [[dagger]] — Build engine (provides both pipelines)
