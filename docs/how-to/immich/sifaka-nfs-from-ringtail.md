---
title: Sifaka NFS Photos from Ringtail
modified: 2026-11-28
last-reviewed: 2026-11-28
tags:
  - how-to
  - operations
  - storage
  - nfs
  - sifaka
---

# Sifaka NFS Photos from Ringtail

The Immich library lives at `sifaka:/volume1/photos` and is mounted
into the ringtail `immich` namespace via an NFS PV
(`immich-library-nfs-pv-ringtail` in `argocd/manifests/immich-ringtail/pv-nfs.yaml`),
bound by the `immich-library` PVC (`pvc.yaml`). The minikube-era PV on
indri is gone with the cutover ([[immich-cutover-and-decommission]]).

## Current state

- Sifaka export `/volume1/photos` allows `192.168.1.0/24` and
  `100.64.0.0/10`, with `Squash=No mapping` (see [[sifaka#NFS Exports]]).
  Ringtail (`192.168.1.21`) is inside the first CIDR, so no DSM rule
  change was needed.
- NFS traffic stays on the LAN: `sifaka` resolves to `192.168.1.203`,
  not a tailnet `100.x` address.
- Immich has run on ringtail against this mount since the cutover. The
  `immich-ringtail` app is Synced and Healthy with the `immich-library`
  PVC bound.
- ArgoCD (`immich-ringtail`) reports the PV and PVC Synced and the PVC
  Healthy.

## If the mount breaks

- **Permission denied**: check the DSM export rules for `photos` against
  the table in [[sifaka#NFS Exports]]. Do not assume `all_squash`.
- **Mount hangs or times out**: confirm the traffic is on `192.168.1.x`
  and not routed over the tailnet. Sifaka's Tailscale must run in TUN
  mode for NFS over the tailnet ([[troubleshoot-sifaka-nfs]]).
- Pod mount errors show up in pod events. See also
  [[runbook-service-probe-failure]].

## Out of scope

- Migrating photo files. Nothing moves; the library stays on sifaka.
- The `immich-ml-cache` PVC (a separate ML model cache). That's not on
  NFS. It is a regular 10Gi RWO PVC, recreated empty on ringtail in
  [[immich-app-on-ringtail]]; the first ML pod boot repopulates it.
