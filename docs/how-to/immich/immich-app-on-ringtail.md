---
title: Immich App on Ringtail
modified: 2026-11-26
last-reviewed: 2026-11-26
tags:
  - how-to
  - operations
  - immich
---

# Immich App on Ringtail

Runs `immich-server`, `immich-machine-learning`, and `immich-valkey` on
ringtail in the `immich` namespace. The `immich-ringtail` ArgoCD app
(auto-sync, tracks `main`) is the live stack. It went live at the
cutover in [[immich-cutover-and-decommission]]: the tailnet ingress
claims `photos`, Caddy routes `photos.ops.eblu.me` to it, and the
minikube `immich` app is gone.

## Manifests

`argocd/manifests/immich-ringtail/`:

- `deployment-server.yaml`, `deployment-ml.yaml`,
  `deployment-valkey.yaml`, plus the `service*.yaml` files.
- `deployment-ml.yaml` uses `runtimeClassName: nvidia` and requests
  `nvidia.com/gpu: 1`. The image is the `-cuda` tag, set in
  `kustomization.yaml`. Ringtail is single-node, so there is no node
  selector. `argocd/manifests/frigate/` has the GPU pod pattern.
- GPU sharing: `argocd/manifests/nvidia-device-plugin/time-slicing-config.yaml`
  sets `replicas: 4`, so frigate, ollama, and immich-ml can share the
  4080.
- `kustomization.yaml` rewrites `docker.io/valkey/valkey` to the
  amd64 image built by nix on ringtail (`containers/valkey/default.nix`),
  pinned by digest. The upstream tag is not used.
- `pv-nfs.yaml` and `pvc.yaml` mount the sifaka photo library. See
  [[sifaka-nfs-from-ringtail]].
- `ingress-tailscale.yaml` is a ProxyGroup ingress with `tls.hosts:
  [photos]` and no explicit `host:`. The staging name `photos-ringtail`
  was retired at cutover.

## Bring-up history

The stack was staged against a copy of the database before cutover
([[immich-pg-data-migration#Dry run before real cutover]]). The
`immich-ringtail` app was manual-sync during that window and is now
auto-sync.

## Verification

- `argocd app get immich-ringtail` reports Synced and Healthy.
- All three pods are Ready, and the ML pod has the GPU attached
  (`nvidia-smi` in the container shows the 4080). These need `kubectl`,
  so they are checked from a host, not from a remote agent session.
- `immich-server` connects to pg and valkey with no `ECONNREFUSED` in
  its logs.
- `photos.ops.eblu.me` loads the Immich web UI.

## Out of scope

- Renaming `immich-ringtail` back to `immich` and the other post-cutover
  cleanup. See the "After cutover" section of
  [[immich-cutover-and-decommission]].
