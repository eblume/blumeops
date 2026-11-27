---
title: Immich Postgres Cluster on Ringtail
modified: 2026-11-27
last-reviewed: 2026-11-27
tags:
  - how-to
  - operations
  - postgres
  - immich
---

# Immich Postgres Cluster on Ringtail

The `immich-pg` CNPG Cluster on ringtail. It was stood up on 2026-05-13
and promoted to primary during the data migration
([[immich-pg-data-migration]], Option A). It is live: the ArgoCD app
`databases-ringtail` is Synced and Healthy. The sections below record how
it was built and how to verify it.

## How it was built

- Manifests live in `argocd/manifests/databases-ringtail/`, deployed by
  the ArgoCD app `argocd/apps/databases-ringtail.yaml` (destination
  ringtail, namespace `databases`).
- `immich-pg.yaml` — CNPG Cluster CR. Image
  `ghcr.io/tensorchord/cloudnative-vectorchord:17-0.5.0`,
  `storage.size: 10Gi`, `storageClass: local-path`, managed `borgmatic`
  role with `pg_read_all_data`, and `shared_preload_libraries: vchord.so`.
  The `externalClusters` and `bootstrap.pg_basebackup` blocks from the
  migration were pruned after promotion, so the manifest carries no
  bootstrap source.
- `external-secret-immich-borgmatic.yaml` — ExternalSecret
  `immich-pg-borgmatic`, from the `borgmatic` item in the blumeops vault
  via the `onepassword-blumeops` ClusterSecretStore.
- `service-immich-pg-tailscale.yaml` — Tailscale LoadBalancer
  `immich-pg.tail8d86e.ts.net:5432`. The Immich deployment connects to
  `immich-pg-rw.databases.svc.cluster.local`
  (`argocd/manifests/immich-ringtail/deployment-server.yaml`).

## Verification

- Cluster is Healthy: `argocd app get databases-ringtail` shows
  `immich-pg` Synced and Healthy (checked 2026-11-27).
- `borgmatic` role: `login: true` and `pg_read_all_data` in
  `managed.roles`. The live role state is not checked by the manifest
  review; confirm with `psql` from a host that can reach the cluster.
- ExternalSecret `immich-pg-borgmatic`: Synced and Healthy in ArgoCD.
- Extensions (`vchord`, `vector`, `cube`, `earthdistance`): the manifest
  has no `initdb` or `postInitSQL` block, so nothing in the Cluster CR
  installs them. The image provides them, `vchord.so` is preloaded, and
  Immich creates the extensions in its own `immich` database at startup.
  Confirm the live state with `\dx` from `psql -U postgres`.

## Borgmatic

The backup flip to the ringtail cluster is done. Indri's Caddy proxy
maps port 5433 to `immich-pg.tail8d86e.ts.net:5432`
(`darwin/indri/caddy-services.json`), and the borgmatic pgpass entry for
`pg.ops.eblu.me:5433` (`darwin/indri/configuration.nix`) uses that port.
The cutover steps are in [[immich-cutover-and-decommission]].

## Out of scope

- Importing data: [[immich-pg-data-migration]]. Option A is complete.
