---
title: Immich Postgres Data Migration
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - postgres
  - immich
  - critical
---

# Immich Postgres Data Migration

**This is the data-loss surface of the migration.** Pick a method,
prove it on a throwaway copy first, then run the real cutover.

## Decision: pick one

### Option A — CNPG `externalCluster` bootstrap (preferred)

Stand the ringtail cluster up as a streaming replica of the minikube
cluster via `bootstrap.pg_basebackup.source`. Replica catches up
online; when ready, promote it and point Immich at it. This is
CNPG's documented PG-to-PG migration path and gives near-zero data
loss (the WAL position at promote == the position at app stop).

Requires: network path from ringtail to minikube's pg over the
tailnet (the existing `immich-pg-tailscale` Service works), and a
superuser secret minikube-side exposed to ringtail's basebackup.

Pitfall to plan around: the ringtail Cluster CR will need its
`bootstrap` block rewritten *after* promotion (CNPG doesn't
gracefully drop the externalCluster reference). Account for this in
[[immich-pg-on-ringtail]] — it may force a reset of that card.

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

Whichever option wins:

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

- Row counts match for `assets`, `albums`, `users`, `face`,
  `asset_face`, `smart_search` (the embedding table) — script this.
- `pg_dump --schema-only --no-owner` diff between source and dest
  should be empty modulo CNPG-managed roles.
- Immich `/api/server-info/version` and `/api/server-info/statistics`
  return sane numbers.

## Rollback

If the cutover fails verification: stop the ringtail immich, repoint
ArgoCD `immich.destination` back to minikube, re-sync. Source pg was
never deleted. Document what failed and reset the chain.
