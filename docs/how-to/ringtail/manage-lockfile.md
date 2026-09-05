---
title: Manage Ringtail Lockfile
modified: 2026-07-17
last-reviewed: 2026-07-17
tags:
  - how-to
  - ringtail
  - nix
---

# Manage Ringtail Lockfile

Two flows update the ringtail NixOS flake lockfile (`nixos/ringtail/flake.lock`) for different purposes.

## Update All Inputs

To pull the latest versions of all flake inputs (equivalent to `nix flake update`):

```bash
# 1. Update flake.lock. Local equivalent of the Ringtail Flake Update
#    workflow's script, run in a nixos/nix container because gilbert has no
#    nix (the workflow itself runs nix natively on the ringtail nix runner).
docker run --rm -i -v "$PWD":/workspace -w /workspace/nixos/ringtail \
    -e SKIP_INPUTS=nixpkgs-services nixos/nix:2.34.4 sh -s <<'SH'
set -e;
# Double quotes: single quotes would keep $SKIP_INPUTS literal and
# silently disable the skip filter (letting `nix flake update`
# bump the deliberately-pinned nixpkgs-services input).
SKIP="$SKIP_INPUTS";
# Land the metadata in a real file: nix-instantiate cannot
# readFile a pipe (/dev/stdin canonicalizes to
# /proc/<pid>/fd/pipe:[...] and readFile fails), which made
# discovery silently empty for as long as this pipeline existed.
# No stderr suppression — metadata failures should be visible.
nix --extra-experimental-features 'nix-command flakes' \
  flake metadata --json > /tmp/flake-meta.json;
ALL=$(nix-instantiate --eval -E "builtins.concatStringsSep \" \" (builtins.attrNames (builtins.fromJSON (builtins.readFile /tmp/flake-meta.json)).locks.nodes.root.inputs)" | tr -d '"');
INPUTS='';
for i in $ALL; do
  case ",$SKIP," in *",$i,"*) continue ;; esac;
  INPUTS="$INPUTS $i";
done;
echo "Updating inputs:$INPUTS";
echo "Skipping: $SKIP";
# Empty INPUTS would make `nix flake update` update *all* inputs,
# including the ones we meant to skip — fail loudly instead.
[ -n "$INPUTS" ] || { echo "no inputs discovered; refusing bare flake update" >&2; exit 1; };
nix --extra-experimental-features 'nix-command flakes' \
  flake update $INPUTS --accept-flake-config
SH

# 2. Commit, push, then deploy
git add nixos/ringtail/flake.lock
git commit -m "Update ringtail flake inputs"
git push
mise run provision-ringtail
```

After deploying, continue with [post-deploy maintenance](#post-deploy-maintenance).

### From a Remote-Agent Session

Remote-agent sessions have no nix, docker, or deploy access, so the update
runs in CI instead: the agent opens a branch/PR, then a human dispatches the
**Ringtail Flake Update** workflow (Actions > Ringtail Flake Update > Run
workflow, selecting the PR branch). The workflow runs `nix flake update`
directly on ringtail's nix runner and pushes the refreshed `flake.lock`
as a commit on that branch for review. After merge, a human deploys with
`mise run provision-ringtail` from gilbert and continues with
[post-deploy maintenance](#post-deploy-maintenance).

## Lock New Inputs Only

`mise run provision-ringtail` automatically runs `nix flake lock` in a
nixos/nix container before deploying. This resolves any newly added inputs
without upgrading existing ones. If the lockfile changes, the task stages the
file and exits — commit, push, and re-run.

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
- [[dagger]] — Build engine
