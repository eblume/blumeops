---
title: Sifaka NFS Photos from Ringtail
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - storage
  - nfs
  - sifaka
---

# Sifaka NFS Photos from Ringtail

The Immich library lives at `sifaka:/volume1/photos` and is mounted
into the pod via an NFS PV (see `argocd/manifests/immich/pv-nfs.yaml`).
That PV is currently scoped to indri. We need ringtail to mount the
same path with the same RWX semantics, without breaking the existing
indri mount during the transition.

## What to verify / do

- Check `sifaka` DSM NFS rules for the `photos` share. Per
  [[shower-on-ringtail#NFS + SMB share on sifaka]] convention, rules
  use `192.168.1.0/24` + `100.64.0.0/10` with
  `all_squash`/`Map all users to admin`. The existing rule may
  already cover ringtail (it's on `192.168.1.21` per the recent
  static-IP pin). If so this card is a verification card.
- If the rule is locked to indri's IP: add an entry for ringtail
  (192.168.1.21) or widen to the subnet pattern above.
- Test mount from a ringtail debug pod (busybox or alpine with
  nfs-utils) against the `photos` share. Read a file. Write a temp
  file. Delete it.
- Watch for the known sifaka NFS-over-Tailscale gotcha: sifaka's
  Tailscale must be in TUN mode (not userspace) for NFS to work
  reliably over the tailnet. The NFS path here goes over the LAN
  (not tailnet), so this shouldn't bite, but worth confirming the
  NFS traffic is on `192.168.1.x` not `100.x`.

## PV + PVC on ringtail

- New `pv-nfs.yaml` mirroring the minikube one (name can be shared
  if the PV is cluster-scoped — but PVs are per-cluster, so just
  duplicate). Same `server: sifaka`, same path, same
  `accessModes: [ReadWriteMany]`, `persistentVolumeReclaimPolicy:
  Retain`.
- New `pvc.yaml` in the ringtail `immich` namespace bound to it.
- The minikube PVC stays bound and active until cutover — both
  clusters can have the share NFS-mounted simultaneously (NFS RWX
  permits this). Immich itself must not be running on both sides
  at once.

## Verification

- A pod on ringtail can `ls /mnt/photos/` and see the same files
  as the indri pod.
- File written from ringtail pod is visible from indri pod and
  vice versa (proves there's no caching surprise).

## Out of scope

- Migrating photo files. Nothing moves; this is just adding a second
  NFS client.
- The `pvc-ml-cache.yaml` PVC (a separate ML model cache). That's
  not on NFS — it's a regular PVC. Recreated empty on ringtail in
  [[immich-app-on-ringtail]]; the first ML pod boot will repopulate
  it.
