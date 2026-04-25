---
title: Restore Mealie from Borg
modified: 2026-04-24
last-reviewed: 2026-04-24
tags:
  - how-to
  - mealie
  - backup
---

# Restore Mealie from Borg

How to restore [[mealie]]'s SQLite database from a [[borgmatic]] archive when data has been lost (e.g. PVC wiped, accidental deletion, post-DR rebuild).

## Prerequisites

- SSH access to [[indri]] (where borgmatic runs and stores k8s SQLite dumps)
- Mealie deployment present in the cluster (the PVC `mealie-data` exists in namespace `mealie`)
- Know which borg archive predates the data loss

## Procedure

### 1. Identify a Pre-Loss Archive

List archives and pick one before the incident:

```bash
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg | tail -30'
```

Compare dump sizes across archives if you're unsure when the loss happened — the daily borgmatic run captures `/Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db`. A sudden drop in size signals the wipe:

```bash
ssh indri 'bash -c "BORG_PASSCOMMAND=\"cat /Users/erichblume/.borg/config.yaml\" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg::<archive-name> \
  --pattern=+Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db"'
```

### 2. Extract the Pre-Loss Dump

```bash
ssh indri 'mkdir -p ~/tmp/mealie-restore && cd ~/tmp/mealie-restore && \
  BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg extract /Volumes/backups/borg::<archive-name> \
  Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db'
```

The file lands at `~/tmp/mealie-restore/Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db` (borg preserves the full path).

### 3. Verify the Extracted DB

```bash
ssh indri 'sqlite3 ~/tmp/mealie-restore/Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db \
  "PRAGMA integrity_check; SELECT COUNT(*) FROM recipes; SELECT COUNT(*) FROM users;"'
```

Expect `ok` and non-zero recipe/user counts.

### 4. Snapshot the Current (Wiped) DB

Belt and suspenders — keep a copy of the live DB before overwriting, in case the restore goes wrong:

```bash
ssh indri 'bash -c "kubectl --context=minikube -n mealie exec deploy/mealie -- \
  python3 -c \"import sqlite3; sqlite3.connect(\\\"/app/data/mealie.db\\\").backup(sqlite3.connect(\\\"/tmp/wiped-mealie.db\\\"))\" && \
  POD=\$(kubectl --context=minikube -n mealie get pod -l app=mealie -o jsonpath=\"{.items[0].metadata.name}\") && \
  kubectl --context=minikube cp mealie/\$POD:/tmp/wiped-mealie.db /Users/erichblume/tmp/mealie-restore/wiped-mealie.db"'
```

### 5. Scale Mealie Down

The PVC is `ReadWriteOnce`, so the helper pod can't mount it while mealie is running:

```bash
ssh indri 'kubectl --context=minikube -n mealie scale deploy/mealie --replicas=0 && \
  kubectl --context=minikube -n mealie wait --for=delete pod -l app=mealie --timeout=60s'
```

### 6. Start a Helper Pod on the PVC

```bash
ssh indri 'bash -c "cat > /tmp/mealie-helper.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mealie-restore
  namespace: mealie
spec:
  restartPolicy: Never
  containers:
    - name: helper
      image: alpine:3.20
      command: [\"sh\", \"-c\", \"sleep 3600\"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: mealie-data
EOF
kubectl --context=minikube apply -f /tmp/mealie-helper.yaml && \
  kubectl --context=minikube -n mealie wait --for=condition=Ready pod/mealie-restore --timeout=60s"'
```

### 7. Copy and Swap the DB

```bash
ssh indri 'bash -c "kubectl --context=minikube cp \
  /Users/erichblume/tmp/mealie-restore/Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db \
  mealie/mealie-restore:/data/mealie.db.restored && \
  kubectl --context=minikube -n mealie exec mealie-restore -- sh -c \
  \"mv /data/mealie.db /data/mealie.db.wiped && mv /data/mealie.db.restored /data/mealie.db && chown 911:911 /data/mealie.db\""'
```

Mealie's container runs as UID 911. `kubectl cp` preserves the host UID (501 on indri), so the `chown` is required — without it, mealie may fail to write to the DB.

### 8. Tear Down the Helper and Scale Back Up

```bash
ssh indri 'kubectl --context=minikube delete pod -n mealie mealie-restore --wait=true && \
  kubectl --context=minikube -n mealie scale deploy/mealie --replicas=1 && \
  kubectl --context=minikube -n mealie wait --for=condition=Available deploy/mealie --timeout=120s'
```

### 9. Verify the Restore is Live

```bash
ssh indri 'bash -c "kubectl --context=minikube -n mealie exec deploy/mealie -- \
  python3 -c \"import sqlite3; c=sqlite3.connect(\\\"/app/data/mealie.db\\\"); \
  print(\\\"recipes:\\\", c.execute(\\\"select count(*) from recipes\\\").fetchone()[0]); \
  print(\\\"users:\\\", c.execute(\\\"select count(*) from users\\\").fetchone()[0])\""'
```

The counts should match what you saw in step 3.

### 10. Clean Up

Once mealie is working and you've confirmed the data, remove the in-PVC safety copy:

```bash
ssh indri 'kubectl --context=minikube -n mealie exec deploy/mealie -- rm -f /app/data/mealie.db.wiped'
```

Leave the host-side copy at `~/tmp/mealie-restore/wiped-mealie.db` until the next borgmatic run captures the restored state, in case you need to roll back.

## Notes

- The active kubectl context for mealie is `minikube` on [[indri]] until the [[ringtail]] migration completes. Update the `--context` flag if mealie has moved.
- OIDC sign-ins after the wipe may have created new user rows; the restored DB will replace them. Affected users will sign in fresh and Authentik will re-link them on next login.

## Related

- [[mealie]] — Service reference
- [[borgmatic]] — Backup tooling
- [[restore-1password-backup]] — Similar restore pattern for 1Password
