---
title: Immich Postgres Cluster on Ringtail
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - postgres
  - immich
---

# Immich Postgres Cluster on Ringtail

Stand up a fresh `immich-pg` CNPG Cluster on ringtail, ready to receive
data. **No data import yet** — that's [[immich-pg-data-migration]].

## What to do

- Create `argocd/manifests/databases-ringtail/` (or pick another
  namespace name — verify what other ringtail pg clusters will use;
  if none yet, `databases` is fine).
- Port these from the minikube side:
  - `immich-pg.yaml` — CNPG Cluster CR. Same image
    (`ghcr.io/tensorchord/cloudnative-vectorchord:17-0.5.0`), same
    extensions, same managed `borgmatic` role. Bump `storage.size` if
    the minikube 10 GiB looks tight (check actual usage first).
    `storageClass: local-path` on ringtail (default).
  - `external-secret-immich-borgmatic.yaml` — same 1Password item,
    same field, but referencing the ringtail `ClusterSecretStore`
    (`onepassword-blumeops` already exists per the
    `external-secrets-ringtail` app).
  - Service for in-cluster access (the operator creates `immich-pg-rw`
    etc. automatically; verify the app deployment uses those names).
  - A Tailscale Service if we want backups to keep working via the
    same hostname during the transition — see "Borgmatic" below.
- New ArgoCD app `argocd/apps/databases-ringtail.yaml` pointing at
  the new path, destination ringtail.

## Verification

- Cluster reaches `Ready`.
- `borgmatic` role exists, `rolcanlogin=t`, and is a member of
  `pg_read_all_data` (via `managed.roles[].inRoles`).
- ExternalSecret `immich-pg-borgmatic` syncs from 1Password
  (`Ready: True`) and the rendered Secret has `username=borgmatic`.
- The `vchord`, `vector`, `cube`, `earthdistance` extensions show
  installed in the `postgres` database (`\dx` from
  `psql -U postgres`). They are NOT installed in the `immich`
  database at this point — `postInitSQL` in CNPG's `initdb` block
  runs against the `postgres` superuser database. The Immich app
  itself creates the extensions in its own `immich` database at
  startup; do not be alarmed by their absence pre-immich-deploy.
  The `vchord.so` library is preloaded via
  `shared_preload_libraries` regardless, so `CREATE EXTENSION` at
  app startup just registers it in the right database.

## Borgmatic implications

`borgmatic.cfg` on indri targets `immich-pg-tailscale` over the
tailnet. During migration both clusters will exist briefly. Decide
upfront: backup the *source* pg until cutover, then flip borgmatic
to the ringtail Tailscale service. Document the flip in
[[immich-cutover-and-decommission]].

## Out of scope

- Importing data. That is [[immich-pg-data-migration]], which may
  drive a reset on this card if the migration approach (e.g. CNPG
  `externalCluster` bootstrap) requires changes to this Cluster CR.
