---
title: Immich App on Ringtail
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - immich
---

# Immich App on Ringtail

Bring up `immich-server`, `immich-machine-learning`, and
`immich-valkey` on ringtail. This card stands the stack up against
the *new* pg cluster — it does not move user traffic. Cutover lives
in [[immich-cutover-and-decommission]].

## What to do

- New manifest dir `argocd/manifests/immich-ringtail/` (the suffix
  matches the `-ringtail` convention used by other apps). Port from
  `argocd/manifests/immich/`:
  - `deployment-server.yaml` — point `DB_HOSTNAME` at the ringtail
    pg service.
  - `deployment-ml.yaml` — use `runtimeClassName: nvidia` + a
    `resources.limits` for `nvidia.com/gpu: 1`. Use the `-cuda` tag
    of the immich-ml image (set in kustomization). Ringtail is
    single-node, so no node selector needed. See
    `argocd/manifests/frigate/` for the existing GPU pod pattern.

    **GPU contention discovery:** ringtail's `nvidia-device-plugin`
    is configured with `timeSlicing.replicas: 2`. Frigate + Ollama
    already consume both virtual slices. Adding immich-ml requires
    bumping the count to >= 3. Edit
    `argocd/manifests/nvidia-device-plugin/configmap.yaml` (or
    wherever the device-plugin config lives) and re-sync the
    `nvidia-device-plugin` ArgoCD app. The plugin pod restarts and
    the new advertised count appears as the node's
    `nvidia.com/gpu` allocatable.
  - `deployment-valkey.yaml` — straight port, BUT use the upstream
    multi-arch `docker.io/valkey/valkey:<version>` image — do NOT
    use the `registry.ops.eblu.me/blumeops/valkey` rewrite in the
    kustomization. That mirror was built on indri (arm64) and is
    single-arch; pulling it on ringtail (amd64) gets `exec format
    error` in CrashLoopBackOff. The mirror should eventually carry
    a multi-arch tag, at which point the rewrite can return.
  - `service*.yaml` — straight port.
  - `pvc-ml-cache.yaml` — straight port (empty `local-path` PVC).
  - `pv-nfs.yaml` + `pvc.yaml` — already covered by
    [[sifaka-nfs-from-ringtail]] (may live in this dir or theirs).
  - `ingress-tailscale.yaml` — ProxyGroup ingress, **must not** set
    an explicit `host:` (or use `host: *`) per the lesson on
    ProxyGroup VIP routing.
    **Hostname collision warning:** the minikube ingress claims the
    Tailscale device name `photos` (`tls.hosts: [photos]`). Two
    devices on the tailnet cannot share that name. While the
    ringtail deployment is being staged it must use a *different*
    `tls.hosts` value (e.g. `photos-ringtail`) so it can coexist
    with the running minikube one. The flip to `photos` happens at
    cutover time, *after* the minikube ingress has been removed.
    See [[immich-cutover-and-decommission#Cutover sequence]].
  - `kustomization.yaml` — same `images:` block (server, ML, valkey).
- New ArgoCD app `argocd/apps/immich-ringtail.yaml` targeting
  ringtail, namespace `immich`. **Manual sync only** until the
  cutover.
- Existing `argocd/apps/immich.yaml` (minikube) stays untouched
  during this card — both apps exist briefly.

## Bring it up against a copy of the DB

Use the throwaway/test path from [[immich-pg-data-migration#Dry run
before real cutover]]: point the ringtail immich at the *test* pg
cluster first, verify the pod boots, the web UI loads (via
`kubectl port-forward`), assets list, ML embeddings query. Then
tear it down.

## Verification

- All three pods Ready.
- ML pod has a GPU attached: `nvidia-smi` inside the container shows
  the 4080.
- `immich-server` connects to pg and valkey (no `ECONNREFUSED` in
  logs).
- A `kubectl port-forward` to the server service shows the Immich
  web UI.

## Out of scope

- Public/tailnet routing flip. Caddy still points at the minikube
  Tailscale ingress until [[immich-cutover-and-decommission]].
- Removing the minikube immich. Same.
