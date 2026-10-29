---
title: Restore the Authentik Database from Borg
modified: 2026-10-29
last-reviewed: 2026-10-29
tags:
  - how-to
  - authentik
  - postgresql
  - backup
---

# Restore the Authentik Database from Borg

How to restore [[authentik]]'s PostgreSQL database from a [[borgmatic]] operational-tier archive into the CloudNativePG cluster `blumeops-pg` (namespace `databases` on ringtail) when the data is lost or corrupted.

## Prerequisites

- SSH access to [[indri]] (where borgmatic runs and the operational tier lives)
- `kubectl` context `k3s-ringtail` with access to namespaces `databases` and `authentik`
- A local `pg_restore` (PostgreSQL 18, matching the dump's client version)
- A pre-loss archive chosen from the operational tier (step 1)

## Procedure

Run steps 4–6 in one shell session: `$POD` is set in step 4 and reused after it.

### 1. Pick a Pre-Loss Archive

```bash
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg-operational | tail -30'
```

Find the authentik dump inside the chosen archive. Borgmatic stores it under its runtime staging path, so match on the suffix:

```bash
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg-operational::<archive-name> \
  --format "{path}{NL}" | grep "postgresql_databases/pg.ops.eblu.me:5434/authentik$"'
```

Keep the printed path for step 3.

### 2. Quiesce Authentik

Authentik must have no writers during the restore:

```bash
kubectl --context=k3s-ringtail -n authentik scale deploy/authentik-server --replicas=0
kubectl --context=k3s-ringtail -n authentik scale deploy/authentik-worker --replicas=0
kubectl --context=k3s-ringtail -n authentik wait --for=delete pod -l app=authentik,component=server --timeout=120s
kubectl --context=k3s-ringtail -n authentik wait --for=delete pod -l app=authentik,component=worker --timeout=120s
```

### 3. Extract the Dump to the Workstation

Substitute the archive name and the path from step 1:

```bash
ssh indri "BORG_PASSCOMMAND='cat /Users/erichblume/.borg/config.yaml' \
  /opt/homebrew/bin/borg extract --stdout /Volumes/backups/borg-operational::<archive-name> '<dump-path>'" > authentik.dump
test -s authentik.dump && pg_restore --list authentik.dump > /dev/null && echo "dump OK"
```

If `pg_restore --list` rejects the file, the dump is not in the custom format; stop and ask before restoring it by hand.

### 4. Create the Target Database

The `blumeops-pg` bootstrap database is `paperless`; `authentik` is created out-of-band (see [[postgresql]]). Find the primary and create the database if it does not exist:

```bash
POD=$(kubectl --context=k3s-ringtail -n databases get pod \
  -l cnpg.io/cluster=blumeops-pg,cnpg.io/instanceRole=primary -o name)

kubectl --context=k3s-ringtail -n databases exec "$POD" -- \
  psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='authentik'" | grep -q 1 \
  || kubectl --context=k3s-ringtail -n databases exec "$POD" -- \
  psql -d postgres -c "CREATE DATABASE authentik OWNER authentik;"
```

### 5. Check the Target Is Empty, Then Restore

`pg_restore` into a non-empty database merges with existing objects and fails partway. Check first; stop if the count is not `0`:

```bash
kubectl --context=k3s-ringtail -n databases exec "$POD" -- \
  psql -d authentik -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"
```

Then restore:

```bash
kubectl --context=k3s-ringtail -n databases exec -i "$POD" -- \
  pg_restore --no-owner --role=authentik --exit-on-error -d authentik < authentik.dump
```

### 6. Verify

Compare the core counts against the expected values from the archive's date (the `authentik_core_*` tables are authentik's user, group and application tables):

```bash
kubectl --context=k3s-ringtail -n databases exec "$POD" -- \
  psql -d authentik -c "SELECT (SELECT count(*) FROM authentik_core_user) AS users, (SELECT count(*) FROM authentik_core_group) AS groups, (SELECT count(*) FROM authentik_core_application) AS applications;"
```

### 7. Restart Authentik

```bash
kubectl --context=k3s-ringtail -n authentik scale deploy/authentik-server --replicas=1
kubectl --context=k3s-ringtail -n authentik scale deploy/authentik-worker --replicas=1
kubectl --context=k3s-ringtail -n authentik rollout status deploy/authentik-server --timeout=180s
```

Log in through SSO and check the blueprint status in the admin UI before declaring the restore done.

## Notes

- Restoring a dump from before an authentik migration makes authentik run its Django migrations on start. Restore into the same authentik version the dump came from, or expect a migration step on boot.
- The `authentik` role's password comes from the `blumeops-pg-authentik` secret and does not change on restore.
- Delete `authentik.dump` from the workstation once the restore is verified: it contains user and token data.

## Related

- [[authentik]] — Service reference
- [[postgresql]] — CNPG clusters and roles
- [[borgmatic]] — Backup tooling and the operational tier
- [[backups]] — Restore notes
