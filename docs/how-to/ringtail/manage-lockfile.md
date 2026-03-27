---
title: Manage Ringtail Lockfile
modified: 2026-03-27
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
# 1. Update flake.lock
dagger call flake-update --src=. --flake-path=nixos/ringtail \
    export --path=nixos/ringtail/flake.lock

# 2. Commit, push, then deploy
git add nixos/ringtail/flake.lock
git commit -m "Update ringtail flake inputs"
git push
mise run provision-ringtail
```

After deploying, continue with [post-deploy maintenance](#post-deploy-maintenance).

## Lock New Inputs Only

`mise run provision-ringtail` automatically runs `flake-lock` before deploying. This resolves any newly added inputs without upgrading existing ones (equivalent to `nix flake lock`). If the lockfile changes, the task stages the file and exits — commit, push, and re-run.

This is the right behavior for provisioning: configuration changes that add a new input get locked, but existing inputs stay pinned until explicitly updated.

## Post-Deploy Maintenance

After `provision-ringtail` completes (whether from a full update or a config change), perform these steps.

### Check for Kernel Update

Compare the booted kernel against the one in the current system profile:

```fish
ssh ringtail 'echo "Booted:  $(uname -r)"; echo "Staged:  $(readlink /run/current-system/kernel | grep -oP "linux-\K[^/]+")"'
```

If they differ, a reboot is needed for the new kernel to take effect. Reboot at a convenient time:

```fish
ssh ringtail 'sudo reboot'
```

> **AI agents:** Do not reboot automatically. Inform the user that a kernel update is pending and suggest they reboot when convenient.

### Prune Old Generations and Garbage Collect

Old NixOS system generations accumulate over time. The `prune-ringtail-generations` task handles pruning and garbage collection together:

```fish
mise run prune-ringtail-generations            # keep 5 most recent + kernel-safe gen
mise run prune-ringtail-generations --dry-run  # preview only
mise run prune-ringtail-generations --keep 3   # keep fewer generations
```

The task keeps the 5 most recent generations plus the most recent generation whose kernel matches the currently **booted** kernel — this preserves a rollback target that won't require a reboot. After pruning, it runs `nix-collect-garbage` to free unreferenced store paths.

## Related

- [[ringtail]] — Host reference
- [[dagger]] — Build engine (provides both pipelines)
