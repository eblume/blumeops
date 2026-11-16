---
title: Restore Mealie from Borg
modified: 2026-11-16
last-reviewed: 2026-11-16
tags:
  - how-to
  - mealie
  - backup
---

# Restore Mealie from Borg

How to restore [[mealie]]'s SQLite database from a [[borgmatic]] archive when data has been lost (e.g. PVC wiped, accidental deletion, post-DR rebuild).

## Prerequisites

- SSH access to [[indri]] (where borgmatic runs and stores k8s SQLite dumps)
- kubectl access to the `k3s-ringtail` context (mealie runs on [[ringtail]]'s k3s). Run the `kubectl` steps from a host that has it, e.g. via `mise run ensure-k3s-ringtail-kubectl-config` on the workstation.
- Mealie deployment present in the cluster (the PVC `mealie-data` exists in namespace `mealie`)
- Know which borg archive predates the data loss

## Procedure

### 1. Identify a Pre-Loss Archive

List archives and pick one before the incident:

```bash
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg-operational | tail -30'
```

The mealie dump rides in the operational tier post-split, in `sifaka-operational`; pre-split archives (and the old `k8s-dumps/` member path) live in `/Volumes/backups/borg` instead. Set the variables below to match the era of the archive you picked, then use them in the steps that follow:

```bash
# post-split (operational tier):
REPO=/Volumes/backups/borg-operational
DUMP=Users/erichblume/.local/share/borgmatic/k8s-dumps-op/mealie.db
# pre-split:
# REPO=/Volumes/backups/borg
# DUMP=Users/erichblume/.local/share/borgmatic/k8s-dumps/mealie.db
```

Keep `REPO` and `DUMP` set in your shell for the rest of the procedure; the `ssh indri` steps read them from there.

Compare dump sizes across archives if you're unsure when the loss happened — the daily borgmatic run captures `/Users/erichblume/.local/share/borgmatic/k8s-dumps-op/mealie.db`. A sudden drop in size signals the wipe:

```bash
ssh indri bash -s <<EOF
BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list "$REPO::<archive-name>" --pattern="+$DUMP"
EOF
```

### 2. Extract the Pre-Loss Dump

```bash
ssh indri bash -s <<EOF
mkdir -p ~/tmp/mealie-restore && cd ~/tmp/mealie-restore
BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg extract "$REPO::<archive-name>" "$DUMP"
EOF
```

The file lands at `~/tmp/mealie-restore/${DUMP}` on indri (borg preserves the full path).

### 3. Verify the Extracted DB

```bash
ssh indri "sqlite3 ~/tmp/mealie-restore/$DUMP 'PRAGMA integrity_check; SELECT COUNT(*) FROM recipes; SELECT COUNT(*) FROM users;'"
```

Expect `ok` and non-zero recipe/user counts.

### 4. Copy the Dump to the kubectl Host

The kubectl steps below run where the `k3s-ringtail` context lives, not on indri. Copy the verified dump there:

```bash
mkdir -p "$HOME/tmp/mealie-restore/$(dirname ${DUMP})"
scp "indri:~/tmp/mealie-restore/$DUMP" ~/tmp/mealie-restore/${DUMP}
```

### 5. Snapshot the Current (Wiped) DB

Belt and suspenders — keep a copy of the live DB before overwriting, in case the restore goes wrong:

```bash
POD=$(kubectl --context=k3s-ringtail -n mealie get pod -l app=mealie -o jsonpath="{.items[0].metadata.name}")
kubectl --context=k3s-ringtail -n mealie exec "$POD" -- \
  python3 -c "import sqlite3; sqlite3.connect('/app/data/mealie.db').backup(sqlite3.connect('/tmp/wiped-mealie.db'))"
kubectl --context=k3s-ringtail cp "mealie/$POD:/tmp/wiped-mealie.db" ~/tmp/mealie-restore/wiped-mealie.db
```

### 6. Scale Mealie Down

The PVC is `ReadWriteOnce`, so the helper pod can't mount it while mealie is running. ArgoCD's `mealie-ringtail` app has automated sync without self-heal, so this replica change persists until step 9 restores it:

```bash
kubectl --context=k3s-ringtail -n mealie scale deploy/mealie --replicas=0
kubectl --context=k3s-ringtail -n mealie wait --for=delete pod -l app=mealie --timeout=60s
```

### 7. Start a Helper Pod on the PVC

```bash
kubectl --context=k3s-ringtail apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: mealie-restore
  namespace: mealie
spec:
  restartPolicy: Never
  # The mealie namespace enforces Pod Security "restricted", so the helper must comply.
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: helper
      image: alpine:3.20
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: mealie-data
YAML
kubectl --context=k3s-ringtail -n mealie wait --for=condition=Ready pod/mealie-restore --timeout=60s
```

### 8. Copy and Swap the DB

```bash
kubectl --context=k3s-ringtail cp \
  ~/tmp/mealie-restore/${DUMP} \
  mealie/mealie-restore:/data/mealie.db.restored
kubectl --context=k3s-ringtail -n mealie exec mealie-restore -- sh -c \
  "mv /data/mealie.db /data/mealie.db.wiped && mv /data/mealie.db.restored /data/mealie.db && chown 1000:1000 /data/mealie.db"
```

Mealie's container runs as UID 1000 (`User = "1000"` in `containers/mealie/default.nix`; the pod's `fsGroup` is also 1000). The helper runs as UID 1000 too, so `kubectl cp` already leaves the copied file owned by 1000; the `chown` is a defensive no-op.

### 9. Tear Down the Helper and Scale Back Up

```bash
kubectl --context=k3s-ringtail -n mealie delete pod mealie-restore --wait=true
kubectl --context=k3s-ringtail -n mealie scale deploy/mealie --replicas=1
kubectl --context=k3s-ringtail -n mealie wait --for=condition=Available deploy/mealie --timeout=120s
```

### 10. Verify the Restore is Live

```bash
kubectl --context=k3s-ringtail -n mealie exec deploy/mealie -- \
  python3 -c "import sqlite3; c=sqlite3.connect('/app/data/mealie.db'); \
  print('recipes:', c.execute('select count(*) from recipes').fetchone()[0]); \
  print('users:', c.execute('select count(*) from users').fetchone()[0])"
```

The counts should match what you saw in step 3.

### 11. Clean Up

Once mealie is working and you've confirmed the data, remove the in-PVC safety copy:

```bash
kubectl --context=k3s-ringtail -n mealie exec deploy/mealie -- rm -f /app/data/mealie.db.wiped
```

Leave the host-side copy at `~/tmp/mealie-restore/wiped-mealie.db` (on the kubectl host) until the next borgmatic run captures the restored state, in case you need to roll back.

## Notes

- Mealie runs on [[ringtail]]'s k3s (`argocd/apps/mealie-ringtail.yaml`, context `k3s-ringtail`). The indri minikube cluster was retired ([[retire-minikube]]), so older runbooks that used `ssh indri 'kubectl --context=minikube ...'` for mealie are dead.
- OIDC sign-ins after the wipe may have created new user rows; the restored DB will replace them. Affected users will sign in fresh and Authentik will re-link them on next login.

## Related

- [[mealie]] — Service reference
- [[borgmatic]] — Backup tooling
- [[restore-1password-backup]] — Similar restore pattern for 1Password
- [[retire-minikube]] — Why the minikube context is gone
