---
title: Immich Postgres Data Migration
modified: 2026-11-27
last-reviewed: 2026-11-27
tags:
  - how-to
  - operations
  - postgres
  - immich
  - critical
---

# Immich Postgres Data Migration

**This is the data-loss surface of the migration.** The method was
chosen and the migration is complete; this card records how it was done.

## Decision: Option A taken

### Option A — CNPG `externalCluster` bootstrap (taken)

The ringtail cluster was stood up as a streaming replica of the minikube
cluster via `bootstrap.pg_basebackup.source`. The replica caught up
online and was promoted, then Immich was pointed at it. This is
CNPG's documented PG-to-PG migration path and gives near-zero data
loss (the WAL position at promote == the position at app stop).

Requires: network path from ringtail to minikube's pg over the
tailnet (the existing `immich-pg-tailscale` Service works), and a
superuser secret minikube-side exposed to ringtail's basebackup.

After promotion the `externalClusters` and `bootstrap.pg_basebackup`
blocks were pruned from `argocd/manifests/databases-ringtail/immich-pg.yaml`.
Leaving them in would let a `replica.enabled=true` edit try to demote
the cluster against a stale source. The cluster is a standalone primary
now; see [[immich-pg-on-ringtail]].

### Option B — pg_dump / pg_restore

Stop immich, `pg_dump -Fc` from minikube, scp to ringtail, restore.
Simpler but full downtime for the whole dump+restore window
(measure on a copy first — VectorChord indexes are slow to rebuild).
Smaller blast radius; no streaming-replication moving parts.

Use this if Option A hits any blocker. Data loss should still be
zero if the source is stopped first.

### Option C — leave pg on minikube

Rejected. See goal card [[migrate-immich-to-ringtail#Why postgres on
ringtail (not cross-cluster)]].

## Dry run before real cutover

Run before the real cutover, for the chosen method:

1. Snapshot the minikube `immich-pg` PVC or take a fresh `pg_dump`
   into a scratch location.
2. Restore into a *separate* ringtail CNPG cluster (different name,
   e.g. `immich-pg-test`) and point a scratch immich-server pod at
   it.
3. Verify: pod boots, can list assets, ML embeddings query without
   error, face thumbnails render. VectorChord-backed queries should
   not error.
4. Tear the scratch cluster down before doing the real one.

## Verification on the real run

- Row counts match for `asset`, `user`, `album`, `smart_search` (the
  embedding table), `activity`, `asset_face` between source and replica
  before promotion (recorded in the v1.17 changelog).
- `pg_dump --schema-only --no-owner` diff between source and dest
  should be empty modulo CNPG-managed roles.
- Immich `/api/server-info/version` and `/api/server-info/statistics`
  return sane numbers.

## Rollback

Historical. The cutover window is closed: the minikube `immich` app is
gone and ringtail serves `photos` (see [[immich-cutover-and-decommission]]). The rollback that applied during
the window was: stop the ringtail immich, repoint ArgoCD
`immich.destination` back to minikube, re-sync, and leave the source pg
intact until verification passed.
