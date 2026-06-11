---
title: Migrate Wave 1 (paperless, teslamate, mealie) to Ringtail
modified: 2026-06-03
last-reviewed: 2026-06-03
tags:
  - how-to
  - operations
  - ringtail
  - migration
---

# Migrate Wave 1 to Ringtail

Move paperless, teslamate, and mealie off `minikube-indri` and onto
`k3s-ringtail`. This is the load-shedding response to minikube going
OOM: the kernel OOM killer was thrashing the 8 GiB node — killing
`kube-apiserver`, `dockerd`, and the argocd application-controller —
which made every minikube-hosted service probe-flap at once. These
three app pods are ~1.1 GiB resident combined and are the heaviest
non-observability tenants left on minikube. Following
[[migrate-immich-to-ringtail]], the first chain in the indri-k8s
decommission. The final phase — everything else, the forgejo-runner,
and minikube itself — is planned in [[retire-minikube]].

## End state

- `paperless`, `teslamate`, and `mealie` run on ringtail k3s in their
  own namespaces, off minikube entirely.
- A CNPG `blumeops-pg` Cluster runs in a `databases` namespace on
  ringtail (PostgreSQL, owned by ringtail's `cnpg-system` operator),
  holding the `paperless` and `teslamate` databases. Apps reach it
  in-cluster via `blumeops-pg-rw.databases.svc.cluster.local`.
- mealie keeps its SQLite database; its 2 GiB `mealie-data` PVC is
  copied to a ringtail PVC.
- paperless media still lives on [[sifaka]] via NFS (RWX, 500 GiB),
  mounted from ringtail pods. teslamate has no file state.
- Routing: `paperless.ops.eblu.me`, `teslamate.ops.eblu.me`, and
  `mealie.ops.eblu.me` (Caddy on indri) proxy to Tailscale
  ProxyGroup ingresses on ringtail. Service names are unchanged.
- The minikube manifests and the `paperless`/`teslamate`/`mealie`
  databases inside indri's `blumeops-pg` are removed only after
  cutover is verified.

## Non-goals

- Migrating the rest of `blumeops-pg` (e.g. miniflux) — that is a
  later wave. This chain moves only the paperless + teslamate
  databases out; the source cluster on indri stays up for the others.
- Version bumps or config changes. Lift-and-shift only.
- Public (Fly) exposure changes. These stay tailnet-only.
- The observability stack (prometheus/loki/tempo/grafana) — deferred;
  it carries 50 GiB of local TSDB and is the riskiest move.

## Critical constraint: no data loss

**Downtime is acceptable — data loss is not.** We can take each
service fully offline for its cutover, which removes the entire
class of streaming-replication and double-writer hazards. The cold
dump is taken from a *quiesced* source, so it is internally
consistent.

Data surfaces:

1. **paperless postgres** — document metadata, tags, correspondents,
   the search index state. The document *files* are on NFS and never
   move, but losing the DB means files-without-index. This is the
   surface to protect most carefully.
2. **teslamate postgres** — drive/charge history. Re-derivable only
   from Tesla's API for a limited window; treat as unrecoverable.
3. **mealie SQLite** — recipes, meal plans. On the `mealie-data` PVC.

The source databases on indri are **never dropped until the ringtail
side is verified and serving**. Rollback is "repoint and scale back
up," not "restore from backup." [[borgmatic]] remains the backstop.

## Why a fresh CNPG cluster (not cross-cluster pg)

indri's `blumeops-pg` is already exposed tailnet-wide at
`pg.ops.eblu.me` (Caddy L4), so we *could* leave the DBs on indri and
just move the app pods. We are not, because:

- The goal is to retire minikube — keeping pg there blocks it and
  leaves a cross-host runtime dependency (ringtail apps SPOF on
  indri's pg over the tailnet).
- CNPG is the same operator on both clusters; a Cluster CR on ringtail
  is mechanically equivalent to the one on minikube.
- Naming the ringtail cluster `blumeops-pg` in `databases` lets apps
  use the same in-cluster DNS they would on indri.

## Cold-cutover procedure (per service)

Do these one service at a time. paperless first (heaviest, highest
data-sensitivity), then teslamate, then mealie.

### 0. Prerequisites (once, before any service)

- Confirm ringtail's `cnpg-system` operator and `databases` namespace
  are healthy (immich-pg already runs there).
- Confirm ringtail pods can reach indri's `pg.ops.eblu.me:5432` (used
  only to pull the dump) and the sifaka NFS export for paperless
  media. See [[sifaka-nfs-from-ringtail]].
- Define the ringtail `blumeops-pg` CNPG Cluster manifest (model on
  `databases-ringtail/immich-pg.yaml`) and its ExternalSecrets for
  the per-app roles. Sync it; let it come up empty and healthy.

### 1. Quiesce the source

```fish
kubectl --context=minikube-indri -n <ns> scale deploy/<app> --replicas=0
# confirm 0 running, DB now has no writers
```

### 2. Dump from indri, restore to ringtail (postgres apps)

```fish
# dump the single app DB from the quiesced source
kubectl --context=minikube-indri -n databases exec blumeops-pg-1 -- \
  pg_dump -Fc -d <appdb> > /tmp/<appdb>.dump

# restore into the ringtail cluster
kubectl --context=k3s-ringtail -n databases exec -i blumeops-pg-1 -- \
  pg_restore --no-owner --role=<approle> -d <appdb> < /tmp/<appdb>.dump
```

For **mealie** (SQLite) instead: copy the `mealie-data` PVC contents
to the ringtail PVC (e.g. a one-shot rsync pod mounting both, or
`kubectl cp` via a helper pod). Verify the `.db` file size and that
mealie boots read-only against it.

### 3. Verify the restore (before any routing flips)

- Row counts match source for the key tables, scripted:
  - paperless: `documents_document`, `documents_tag`,
    `documents_correspondent`, `auth_user`.
  - teslamate: `cars`, `drives`, `charging_processes`, `positions`.
- `pg_dump --schema-only --no-owner` diff between source and dest is
  empty modulo CNPG-managed roles.
- Boot the app against the ringtail DB on its tailnet name *before*
  Caddy is flipped, and smoke-test (paperless: documents list +
  search; teslamate: dashboard loads recent drives; mealie: recipes
  list).

### 4. Release the service name

```fish
# delete the minikube tailscale ingress so ringtail can claim the name
kubectl --context=minikube-indri -n <ns> delete ingress <app>-tailscale
```

### 5. Bring up on ringtail

- Apply the ringtail manifests (new ArgoCD app `<app>-ringtail`,
  `destination.server` = `https://ringtail.tail8d86e.ts.net:6443`).
  App points at `blumeops-pg-rw.databases.svc.cluster.local`.
- Sync; wait for healthy + the ProxyGroup ingress to get its name.

### 6. Flip routing

- Repoint the Caddy `<app>.ops.eblu.me` upstream at the ringtail
  ProxyGroup ingress (provision-indri, caddy role).
- `mise run services-check` — confirm the service flips from FIRING
  to OK and no neighbours regressed.

### 7. Decommission the source (only after verification)

- Remove the minikube manifests for the app.
- Drop the app DB from indri's `blumeops-pg` (paperless/teslamate)
  **last**, once the ringtail side has served real traffic.

## Rollback

If a cutover fails verification at any step before §7:

- Re-create the minikube tailscale ingress (if §4 ran).
- Scale the minikube app back to `1`.
- Repoint Caddy back to the minikube ingress.
- The source DB was never modified or dropped. Document the failure.
