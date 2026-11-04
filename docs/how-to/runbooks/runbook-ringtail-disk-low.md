---
title: "Runbook: ringtail Root Disk Low"
modified: 2026-11-04
last-reviewed: 2026-11-04
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: ringtail Root Disk Low

**Alert name:** `RingtailRootDiskLow`

ringtail's root filesystem (`/dev/nvme0n1p2`, about 1 TB, mounted at `/`)
has had less than **20% free** for 15 minutes. That one filesystem holds
the k3s containerd image store, every local-path PVC, the nix store and
talos-home, so running out takes down every workload on the node.

## Why 20%

Kubelet acts on its own well before the disk is full:

- **Image GC at 85% used** (about 151 GB free). Kubelet starts deleting
  images, and pods that need them re-pull, which slows every rollout.
- **Hard eviction at 10% free** (about 100 GB). Kubelet evicts pods.

The alert fires at 20% (about 200 GB) so the warning lands before either
of these. Free space normally swings by 150–230 GB a week. The weekly
containerd prune (`nixos/ringtail/containerd-image-prune.nix`) and the
weekly nix-gc (14-day retention) reclaim it, so a dip right before those runs is the usual
trigger.

## Find what grew

```fish
mise run agent-metrics 'last_over_time(talos_home_bytes[1h])'
```

The `component` labels split talos-home: `sessions`, `data`, `rustup`,
the caches, `other`. Since late October, `sessions` (per-session git
worktrees) has been the steady grower. See the session-workspace reaper
below.

On ringtail itself:

```fish
ssh ringtail 'sudo du -xh --max-depth=2 /var/lib | sort -h | tail -15'
```

## Reclaim space

1. **Container images:** run the prune now instead of waiting for its
   timer. On ringtail: `sudo systemctl start containerd-image-prune`.
2. **Nix store:** `ssh ringtail 'sudo nix-collect-garbage --delete-older-than 14d'`.
3. **talos sessions:** the session-workspace reaper only deletes a session
   once it can prove the work is pushed. Check what it is refusing:

   ```logql
   {namespace="talos"} |~ "stale reap of .* skipped|idle reap of .* aborted"
   ```

   If it is refusing most sessions, that's a talos bug: file it there.
   Don't delete session directories by hand while talos is running.

## Resolve

The alert resolves once free space is back above 20%. If the low point
of the weekly cycle keeps falling, the fix is to stop the growth (usually
talos sessions), not to lower the threshold.
