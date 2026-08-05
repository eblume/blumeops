---
title: Migrate Immich to Ringtail
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - immich
  - migration
---

# Migrate Immich to Ringtail

Move the entire Immich stack (server, ML, valkey, postgres) off
`minikube-indri` and onto `k3s-ringtail`. This is the first concrete
chain in the broader indri-k8s decommission: minikube is
memory-saturated (97% RAM, swapping), and Immich is the single
largest tenant (~1.5 GiB resident).

## End state

- Immich `server`, `machine-learning`, and `valkey` Deployments run on
  ringtail k3s in the `immich` namespace.
- The `immich-machine-learning` pod uses ringtail's RTX 4080 via the
  `nvidia-device-plugin` (performance win — currently CPU-only on
  minikube).
- A CNPG `immich-pg` Cluster (PostgreSQL 17 + VectorChord) runs in a
  `databases` namespace on ringtail, owned by the `cnpg-system`
  operator on ringtail.
- The photo library still lives on [[sifaka]] at `/volume1/photos`,
  mounted via NFS from ringtail pods (RWX).
- Routing: `photos.ops.eblu.me` (Caddy on indri) proxies to a
  Tailscale ProxyGroup ingress on ringtail. No public surface today.
- The ArgoCD `immich` app's `destination.server` points at
  `https://ringtail.tail8d86e.ts.net:6443`. The old minikube
  manifests are removed.

## Non-goals

- Public exposure via Fly. Immich stays tailnet-only.
- Changing the immich version or runtime configuration. This is a
  lift-and-shift; bumps come later.
- Backing up to a different target. [[borgmatic]] keeps running on
  indri (it pulls via Tailscale and uses sifaka SMB for the library).

## Critical constraint: no data loss

Downtime is acceptable (Immich is a single-user system; we can take
it offline for the cutover). **Data loss is not.** Two surfaces matter:

1. **Postgres** — face data, ML embeddings (vectors), album state,
   sharing, etc. Re-derivable in theory; weeks of recompute in
   practice. See [[immich-pg-data-migration]].
2. **Library files** — `/volume1/photos`. Not moving, but the NFS
   path must be verified accessible from ringtail before cutover.
   See [[sifaka-nfs-from-ringtail]].

[[borgmatic]] backs both up to sifaka + BorgBase nightly; restore is
possible but slow. Treat it as a fallback, not a plan.

## Why postgres on ringtail (not cross-cluster)

`immich-pg` already has a Tailscale Service we could point ringtail
at, leaving the DB on minikube. We're not doing that because:

- The whole goal is to retire minikube — keeping pg there blocks it.
- Immich is chatty against pg; tailnet round-trips would hurt.
- CNPG is the same operator on both sides — a Cluster CR on ringtail
  is mechanically equivalent.

## Approach

This is a C2 Mikado chain. The prerequisite cards each represent a
distinct surface that has to work before cutover. See
[[agent-change-process#C2 — Mikado Chain]] for the discipline.

## Workflow note: registering new ArgoCD apps during the chain

This chain adds three new ArgoCD `Application` definitions in
`argocd/apps/`: `cloudnative-pg-ringtail`, `databases-ringtail`,
and (later) `immich-ringtail`. The usual branch-and-PR pattern of
`argocd app set <app> --revision <branch> && argocd app sync <app>`
does NOT work for the app-of-apps `apps` Application itself, because
`apps` self-manages: it re-reads `apps.yaml` (which declares
`targetRevision: main`) on every sync and reverts the override. As a
result, new app definitions added on a feature branch are never
visible to the cluster via `apps`.

**Use `kubectl apply` to register each new Application directly:**

```fish
kubectl --context=minikube-indri apply -f argocd/apps/<new-app>.yaml
```

This creates the Application resource out-of-band, bypassing `apps`.

For apps whose source lives in **this** repo (e.g.
`databases-ringtail`, `immich-ringtail` — manifest paths exist only
on the branch until merge), follow the apply with a branch override:

```fish
argocd app set <new-app> --revision mikado/migrate-immich-to-ringtail
argocd app sync <new-app>
```

For apps whose source is an **external** repo at a pinned tag (e.g.
`cloudnative-pg-ringtail` → `mirrors/cloudnative-pg` `v1.27.1`), no
override is needed — the source revision is independent of this PR.

After PR merge:

```fish
argocd app set <new-app> --revision main
argocd app sync <new-app>
```

`apps` itself, on its next sync from `main`, will discover the new
Application definitions in `argocd/apps/` and adopt the already-running
resources without disruption — provided their in-cluster spec matches
the on-disk definitions (which it does because we applied the same
file).

## Related

- [[migrate-wave1-ringtail]] — the next chain in the indri-k8s
  decommission: paperless, teslamate, and mealie
- [[shower-on-ringtail]] — a previous migration to ringtail (simpler:
  no upstream cluster, SQLite, no GPU)
- [[connect-to-postgres]] — getting a psql session against CNPG
- [[ringtail]] — the target cluster
- [[cnpg-on-ringtail]], [[immich-pg-on-ringtail]],
  [[immich-pg-data-migration]], [[sifaka-nfs-from-ringtail]],
  [[immich-app-on-ringtail]], [[immich-cutover-and-decommission]] —
  the prerequisite cards
