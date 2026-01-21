# Phase 6: Kiwix and Transmission Migration

**Goal**: Migrate kiwix-serve and transmission torrent daemon to k8s with shared storage

**Status**: BLOCKED - waiting for [Phase 5.1](P5.1_qemu2_migration.md) (QEMU2 migration)

**Prerequisites**: [Phase 5.1](P5.1_qemu2_migration.md) complete (minikube on QEMU2 driver)

---

## Blocker: Podman Driver Volume Mount Limitations

**First attempt branch:** `feature/p6-kiwix-transmission`

The initial implementation was completed and tested, but **all volume mount approaches failed** due to the podman driver's rootless container limitations:

| Approach | Result |
|----------|--------|
| NFS volume | Failed - CAP_SYS_ADMIN required for NFS mounts |
| SMB CSI driver | Failed - `mount.cifs` returns EPERM inside rootless container |
| `minikube mount` (9p) | Failed - permission denied mounting into podman VM |
| hostPath | Failed - path doesn't exist inside minikube container |

**Root cause:** The podman driver runs minikube in a rootless container that lacks kernel capabilities for filesystem mounts. This is a [documented limitation](https://minikube.sigs.k8s.io/docs/drivers/podman/) of the experimental podman driver.

**Solution:** Phase 5.1 migrates minikube from podman to QEMU2 driver, which creates an actual VM with full kernel capabilities.

**What's preserved:**
- All k8s manifests in `feature/p6-kiwix-transmission` are complete and tested
- Prerequisites (SMB share, k8s-smb user, data rsync) are done
- Can retry P6 immediately after P5.1 completes

---

## Overview

This phase migrates two services that share storage but operate independently:
1. **Transmission** - General-purpose BitTorrent daemon (standalone service)
2. **Kiwix** - Serves ZIM archives via HTTP

The current architecture on indri:
- Transmission downloads torrents to `~/transmission/`
- Ansible syncs a declarative torrent list to transmission
- Completed ZIMs are symlinked to kiwix's serving directory
- kiwix-serve runs as a LaunchAgent with explicit file arguments

New architecture in k8s:
- **SMB volume** on sifaka (`/volume1/torrents`) for all torrent downloads
- **SMB CSI driver** for mounting the Synology share in k8s
- **Transmission** as a standalone service with Tailscale ingress (`torrent.tail8d86e.ts.net`)
- **Kiwix** deployment that watches for `.zim` files among all downloads
- **Declarative ZIM list** in kiwix manifest, synced to transmission automatically
- **CronJob** to detect new ZIMs and restart kiwix

**Key design principles:**
- Transmission is a general-purpose torrent daemon, not just for kiwix
- Users can add arbitrary torrents via transmission web UI/RPC
- Kiwix declares which ZIM torrents it wants and handles syncing them to transmission
- Kiwix watches the shared download directory for any `.zim` files (regardless of how they were added)

---

## Architecture Decisions

### Storage: SMB on Sifaka (or NFS after QEMU2 migration)

**Note:** The original plan chose SMB over NFS, but both failed with podman driver. After QEMU2 migration, either should work. SMB is still preferred for:
- Native Synology SMB support with good macOS compatibility
- ReadWriteMany access mode for concurrent pod access
- SMB CSI driver already mirrored to forge

**Alternative after QEMU2:** NFS may be simpler with `minikube mount` or direct NFS volume type.

**Storage path:** `/volume1/torrents/` on sifaka (SMB share name: `torrents`)
- General-purpose torrent download directory
- Contains ZIM files, Linux ISOs, and whatever else users download
- Accessed via SMB credentials stored in k8s Secret

**No backup needed:**
- Sifaka is RAID 5/6, already the backup target
- ZIM files are re-downloadable via torrent
- Other torrents are typically re-downloadable too
- Future offsite backups will cover all shares

### Torrent Daemon: Transmission (Standalone Service)

**Why stick with Transmission:**
- Proven reliability on indri
- Well-maintained container images (`linuxserver/transmission`)
- RPC API for automation
- DHT/PEX for good peer discovery
- Web UI for interactive management

**Container image:** `lscr.io/linuxserver/transmission:latest`
- Includes web UI for monitoring and adding torrents
- Supports environment variable configuration
- Uses `/downloads` for completed files

**Standalone service:**
- Own namespace: `torrent`
- Own Tailscale ingress: `torrent.tail8d86e.ts.net`
- Can be used for any torrents, not just ZIM archives
- Users interact with it directly via web UI

### Declarative ZIM Torrent Management

**Pattern:** Kiwix ConfigMap → Kiwix Sidecar → Transmission RPC

1. **ConfigMap** (`kiwix-zim-torrents`) in kiwix namespace lists desired ZIM torrent URLs
2. **Kiwix sidecar** syncs ConfigMap to transmission (adds missing torrents)
3. Transmission downloads to shared SMB volume
4. Kiwix watches SMB volume for `.zim` files

This allows adding new ZIM archives by:
1. Adding torrent URL to ConfigMap in kiwix's ArgoCD manifest
2. Syncing the kiwix ArgoCD app
3. Kiwix sidecar adds torrent to transmission
4. Waiting for download to complete
5. Kiwix restarts automatically when ZIM watcher detects the new file

**Non-declarative torrents:**
- Users can add any torrent via `torrent.tail8d86e.ts.net` web UI
- If someone adds a ZIM torrent manually, kiwix will still pick it up
- Non-ZIM downloads coexist in the same directory

### Kiwix Restart Orchestration

**Challenge:** kiwix-serve doesn't hot-reload new ZIM files; requires restart.

**Solution:** CronJob watcher
- Runs hourly (configurable)
- Lists completed `.zim` files in SMB volume (among all downloads)
- Compares with hash of last-seen list
- If changed, triggers `kubectl rollout restart deployment/kiwix`

**Graceful handling of incomplete downloads:**
- Transmission stores incomplete files with `.part` extension
- Kiwix glob pattern `*.zim` only matches completed files
- Kiwix can start immediately with whatever ZIMs exist

---

## Prerequisites (Manual Steps)

### 1. Configure SMB Share on Sifaka

**Status: DONE** - The `torrents` shared folder has been created at `/volume1/torrents`.

### 2. Create Dedicated Synology User for Kubernetes (USER ACTION REQUIRED)

Create a dedicated Synology user for k8s SMB access (do not use personal account):

On Synology DSM (Control Panel → User & Group):
1. Create new user: `k8s-smb` (or similar)
   - Set a strong password
   - No admin privileges needed
   - Deny access to all applications (only needs file services)
2. Set permissions on the `torrents` share:
   - Give `k8s-smb` user Read/Write access
   - Remove or limit other user access as appropriate
3. Store credentials in 1Password:
   - Vault: `vg6xf6vvfmoh5hqjjhlhbeoaie` (blumeops vault)
   - Item name: `synology-smb-k8s`
   - Fields: `username` (k8s-smb), `password`

### 3. Mirror SMB CSI Driver Helm Chart to Forge (USER ACTION REQUIRED)

Mirror the SMB CSI driver chart to forge for GitOps deployment:

```bash
# Clone the upstream chart repo
cd ~/code/3rd
git clone https://github.com/kubernetes-csi/csi-driver-smb.git
cd csi-driver-smb

# Push to forge mirror
git remote add forge ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/csi-driver-smb.git
git push forge --all --tags
```

### 4. Copy Existing Downloads to Sifaka

Before migration, copy existing downloads to avoid re-downloading ~138GB:

```bash
# From indri - mount the SMB share via Finder or command line
open smb://sifaka/torrents

# Then rsync (adjust mount path as needed)
rsync -avP ~/transmission/ /Volumes/torrents/

# Verify ZIM files
ls -la /Volumes/torrents/*.zim
```

### 5. Store SMB Credentials in 1Password

**Note:** This is covered in step 2 above. The 1Password item should be:
- Vault: `vg6xf6vvfmoh5hqjjhlhbeoaie` (blumeops vault)
- Item name: `synology-smb-k8s`
- Fields: `username` (k8s-smb), `password`

---

## Steps

### 1. Deploy SMB CSI Driver via ArgoCD

**File:** `argocd/manifests/smb-csi/values.yaml`

```yaml
# Minimal values - defaults are generally fine
controller:
  replicas: 1
```

**File:** `argocd/apps/smb-csi.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: smb-csi
  namespace: argocd
spec:
  project: default
  sources:
    # Helm chart from forge mirror
    - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/csi-driver-smb.git
      targetRevision: v1.17.0
      path: charts/csi-driver-smb
      helm:
        releaseName: csi-driver-smb
        valueFiles:
          - $values/argocd/manifests/smb-csi/values.yaml
    # Values from our git repo
    - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### 2. Create Shared SMB PersistentVolume

This PV is shared between transmission and kiwix namespaces.

**File:** `argocd/manifests/torrent/pv-smb.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: torrents-smb-pv
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  mountOptions:
    - dir_mode=0777
    - file_mode=0777
    - uid=1000
    - gid=1000
    - noperm
    - mfsymlinks
    - cache=strict
    - noserverino  # Required to prevent data corruption
  csi:
    driver: smb.csi.k8s.io
    volumeHandle: torrents-smb-pv
    volumeAttributes:
      source: //sifaka/torrents
    nodeStageSecretRef:
      name: smbcreds
      namespace: torrent
```

**File:** `argocd/manifests/torrent/secret-smb.yaml.tpl`

```yaml
# Template - apply manually with credentials from 1Password
# kubectl --context=minikube create secret generic smbcreds \
#   --namespace torrent \
#   --from-literal=username=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/synology-smb-k8s/username") \
#   --from-literal=password=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/synology-smb-k8s/password")
apiVersion: v1
kind: Secret
metadata:
  name: smbcreds
  namespace: torrent
type: Opaque
stringData:
  username: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/synology-smb-k8s/username }}"
  password: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/synology-smb-k8s/password }}"
```

---

## Transmission Service (Standalone)

### 3. Create Transmission Namespace Resources

**File:** `argocd/manifests/torrent/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: torrents-storage
  namespace: torrent
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: torrents-smb-pv
  resources:
    requests:
      storage: 1Ti
```

**File:** `argocd/manifests/torrent/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transmission
  namespace: torrent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: transmission
  template:
    metadata:
      labels:
        app: transmission
    spec:
      containers:
        - name: transmission
          image: lscr.io/linuxserver/transmission:latest
          env:
            - name: PUID
              value: "1000"
            - name: PGID
              value: "1000"
            - name: TZ
              value: "America/Los_Angeles"
          ports:
            - containerPort: 9091
              name: web
            - containerPort: 51413
              name: peer-tcp
            - containerPort: 51413
              protocol: UDP
              name: peer-udp
          volumeMounts:
            - name: downloads
              mountPath: /downloads
            - name: config
              mountPath: /config
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /transmission/web/
              port: 9091
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /transmission/web/
              port: 9091
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: downloads
          persistentVolumeClaim:
            claimName: torrents-storage
        - name: config
          emptyDir: {}  # Config is ephemeral; torrents persist in SMB
```

**File:** `argocd/manifests/torrent/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: transmission
  namespace: torrent
spec:
  selector:
    app: transmission
  ports:
    - name: web
      port: 9091
      targetPort: 9091
```

**File:** `argocd/manifests/torrent/ingress-tailscale.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: transmission
  namespace: torrent
spec:
  ingressClassName: tailscale
  rules:
    - host: torrent
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: transmission
                port:
                  number: 9091
```

**File:** `argocd/manifests/torrent/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: torrent
resources:
  - pv-smb.yaml
  - secret-smb.yaml.tpl
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - ingress-tailscale.yaml
```

**File:** `argocd/apps/torrent.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: torrent
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/torrent
  destination:
    server: https://kubernetes.default.svc
    namespace: torrent
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

---

## Kiwix Service

### 3. Create Kiwix PVC (References Same PV)

**File:** `argocd/manifests/kiwix/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: torrents-storage
  namespace: kiwix
spec:
  accessModes:
    - ReadWriteMany  # Need write for the sync sidecar to work
  storageClassName: ""
  volumeName: torrents-smb-pv
  resources:
    requests:
      storage: 1Ti
```

### 4. Create Declarative ZIM Torrent List ConfigMap

This ConfigMap lists the ZIM archives that kiwix wants. The kiwix sidecar syncs these to transmission.

**File:** `argocd/manifests/kiwix/configmap-zim-torrents.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiwix-zim-torrents
  namespace: kiwix
data:
  torrents.txt: |
    # Declarative ZIM archive torrent URLs
    # These are synced to transmission automatically by the kiwix sidecar
    # Format: one URL per line, comments start with #
    #
    # Users can also add ZIM torrents manually via torrent.tail8d86e.ts.net
    # and kiwix will pick them up automatically.

    # Wikipedia - Top 1M English articles (43G)
    https://download.kiwix.org/zim/wikipedia/wikipedia_en_top1m_maxi_2025-09.zim.torrent

    # Project Gutenberg - Public domain books (72G)
    https://download.kiwix.org/zim/gutenberg/gutenberg_en_all_2023-08.zim.torrent

    # iFixit - Repair guides (3.3G)
    https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-12.zim.torrent

    # Stack Exchange
    https://download.kiwix.org/zim/stack_exchange/superuser.com_en_all_2025-12.zim.torrent
    https://download.kiwix.org/zim/stack_exchange/math.stackexchange.com_en_all_2025-12.zim.torrent

    # LibreTexts - Open educational resources
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_bio_2025-01.zim.torrent
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_chem_2025-01.zim.torrent
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_eng_2025-01.zim.torrent
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_math_2025-01.zim.torrent
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_phys_2025-01.zim.torrent
    https://download.kiwix.org/zim/libretexts/libretexts.org_en_human_2025-01.zim.torrent

    # DevDocs - Programming documentation
    https://download.kiwix.org/zim/devdocs/devdocs_en_bash_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_python_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_go_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_kubernetes_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_docker_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_git_2026-01.zim.torrent
    https://download.kiwix.org/zim/devdocs/devdocs_en_postgresql_2026-01.zim.torrent
    # Add more from ansible/roles/kiwix/defaults/main.yml as needed
```

### 5. Create Torrent Sync Script ConfigMap

This script syncs the declarative ZIM list to transmission.

**File:** `argocd/manifests/kiwix/configmap-sync-script.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: zim-torrent-sync-script
  namespace: kiwix
data:
  sync-zim-torrents.sh: |
    #!/bin/bash
    # Sync ZIM torrents from kiwix ConfigMap to Transmission
    # Runs as a sidecar in the kiwix deployment
    set -euo pipefail

    TORRENT_LIST="${TORRENT_LIST:-/config/torrents.txt}"
    TRANSMISSION_HOST="${TRANSMISSION_HOST:-transmission.torrent.svc.cluster.local}"
    TRANSMISSION_PORT="${TRANSMISSION_PORT:-9091}"

    echo "Syncing ZIM torrents to transmission at ${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"

    # Wait for transmission to be ready
    echo "Waiting for Transmission RPC..."
    max_attempts=30
    attempt=0
    until curl -sf "http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc" >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            echo "Transmission not ready after ${max_attempts} attempts, will retry next cycle"
            exit 0  # Don't fail, just skip this sync
        fi
        sleep 10
    done
    echo "Transmission is ready"

    # Get current torrents from transmission
    # transmission-remote returns header + data + footer, extract just torrent names
    current=$(transmission-remote "${TRANSMISSION_HOST}:${TRANSMISSION_PORT}" -l 2>/dev/null | \
              tail -n +2 | head -n -1 | awk '{print $NF}' || true)

    added=0
    skipped=0

    while IFS= read -r url || [[ -n "$url" ]]; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace
        url=$(echo "$url" | xargs)
        [[ -z "$url" ]] && continue

        # Extract base name from URL (remove .torrent extension)
        basename=$(basename "$url" .torrent)
        # Also try without .zim in case transmission reports it differently
        basename_no_zim="${basename%.zim}"

        # Check if already in transmission
        if echo "$current" | grep -qF "$basename_no_zim"; then
            ((skipped++)) || true
        else
            if transmission-remote "${TRANSMISSION_HOST}:${TRANSMISSION_PORT}" -a "$url" 2>/dev/null; then
                echo "Added: $basename"
                ((added++)) || true
            else
                echo "Warning: Failed to add $url" >&2
            fi
        fi
    done < "$TORRENT_LIST"

    echo "Sync complete: $added added, $skipped already present"
```

### 6. Deploy Kiwix with Torrent Sync Sidecar

**File:** `argocd/manifests/kiwix/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kiwix
  namespace: kiwix
  annotations:
    # Track ZIM file changes for restart detection
    kiwix.blumeops/zim-hash: ""
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kiwix
  template:
    metadata:
      labels:
        app: kiwix
    spec:
      containers:
        # Main kiwix-serve container
        - name: kiwix-serve
          image: ghcr.io/kiwix/kiwix-serve:3.8.1
          args:
            - --port=80
            - /data/*.zim  # Serves ALL .zim files, regardless of how they were added
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: torrents
              mountPath: /data
              readOnly: true
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10

        # Sidecar: Syncs declarative ZIM torrents to transmission
        - name: torrent-sync
          image: lscr.io/linuxserver/transmission:latest  # Has transmission-remote CLI
          command: ["/bin/bash", "-c"]
          args:
            - |
              echo "Starting ZIM torrent sync sidecar"
              # Initial sync
              /scripts/sync-zim-torrents.sh || echo "Initial sync failed, will retry"
              # Periodic sync every 30 minutes
              while true; do
                sleep 1800
                /scripts/sync-zim-torrents.sh || echo "Sync failed, will retry"
              done
          env:
            - name: TRANSMISSION_HOST
              value: "transmission.torrent.svc.cluster.local"
            - name: TRANSMISSION_PORT
              value: "9091"
            - name: TORRENT_LIST
              value: "/config/torrents.txt"
          volumeMounts:
            - name: zim-torrents-config
              mountPath: /config/torrents.txt
              subPath: torrents.txt
            - name: sync-script
              mountPath: /scripts
          resources:
            requests:
              memory: "32Mi"
              cpu: "10m"
            limits:
              memory: "64Mi"

      volumes:
        - name: torrents
          persistentVolumeClaim:
            claimName: torrents-storage
        - name: zim-torrents-config
          configMap:
            name: kiwix-zim-torrents
        - name: sync-script
          configMap:
            name: zim-torrent-sync-script
            defaultMode: 0755
```

**File:** `argocd/manifests/kiwix/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kiwix
  namespace: kiwix
spec:
  selector:
    app: kiwix
  ports:
    - name: http
      port: 80
      targetPort: 80
```

### 7. Create Tailscale Ingress for Kiwix

**File:** `argocd/manifests/kiwix/ingress-tailscale.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kiwix
  namespace: kiwix
spec:
  ingressClassName: tailscale
  rules:
    - host: kiwix
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kiwix
                port:
                  number: 80
```

### 8. Create ZIM Watcher CronJob

This CronJob runs hourly to detect new completed ZIMs (from any source) and triggers a kiwix restart.

**File:** `argocd/manifests/kiwix/cronjob-zim-watcher.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: zim-watcher
  namespace: kiwix
spec:
  schedule: "0 * * * *"  # Every hour
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: zim-watcher
          containers:
            - name: watcher
              image: bitnami/kubectl:latest
              command: ["/bin/bash", "-c"]
              args:
                - |
                  set -euo pipefail

                  # Get current ZIM files (among all downloads)
                  # This picks up ZIMs from both declarative list AND manually added torrents
                  current_zims=$(ls -1 /data/*.zim 2>/dev/null | sort | md5sum | cut -d' ' -f1 || echo "empty")

                  # Get stored hash from deployment annotation
                  stored_hash=$(kubectl get deployment kiwix -n kiwix -o jsonpath='{.metadata.annotations.kiwix\.blumeops/zim-hash}' 2>/dev/null || echo "")

                  echo "Current ZIMs hash: $current_zims"
                  echo "Stored hash: $stored_hash"

                  # Also list what ZIMs we found
                  echo "ZIM files found:"
                  ls -la /data/*.zim 2>/dev/null || echo "  (none)"

                  if [[ "$current_zims" != "$stored_hash" && "$current_zims" != "empty" ]]; then
                    echo "ZIM files changed, restarting kiwix deployment..."
                    kubectl annotate deployment kiwix -n kiwix "kiwix.blumeops/zim-hash=$current_zims" --overwrite
                    kubectl rollout restart deployment/kiwix -n kiwix
                    echo "Restart triggered"
                  else
                    echo "No changes detected"
                  fi
              volumeMounts:
                - name: torrents
                  mountPath: /data
                  readOnly: true
          restartPolicy: OnFailure
          volumes:
            - name: torrents
              persistentVolumeClaim:
                claimName: torrents-storage
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: zim-watcher
  namespace: kiwix
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: zim-watcher
  namespace: kiwix
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: zim-watcher
  namespace: kiwix
subjects:
  - kind: ServiceAccount
    name: zim-watcher
    namespace: kiwix
roleRef:
  kind: Role
  name: zim-watcher
  apiGroup: rbac.authorization.k8s.io
```

### 9. Create Kiwix Kustomization

**File:** `argocd/manifests/kiwix/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kiwix
resources:
  - pvc.yaml
  - configmap-zim-torrents.yaml
  - configmap-sync-script.yaml
  - deployment.yaml
  - service.yaml
  - ingress-tailscale.yaml
  - cronjob-zim-watcher.yaml
```

### 10. Create Kiwix ArgoCD Application

**File:** `argocd/apps/kiwix.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kiwix
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/kiwix
  destination:
    server: https://kubernetes.default.svc
    namespace: kiwix
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

---

## Deployment Sequence

### Phase A: Storage Setup (Manual)

1. **Configure SMB share on sifaka** (see Prerequisites section)
2. **Copy existing downloads:**
   ```bash
   ssh indri 'rsync -avP ~/transmission/ sifaka:/volume1/torrents/'
   ```
3. **Verify SMB access from indri:**
   ```bash
   # Test SMB mount via Finder or smbclient
   smbclient -L //sifaka -U eblume
   ```

### Phase B: Deploy Transmission to Kubernetes

Deploy transmission first since kiwix depends on it.

1. **Create feature branch** (if not already done)
2. **Add torrent manifests** to `argocd/manifests/torrent/`
3. **Add ArgoCD Application** to `argocd/apps/torrent.yaml`
4. **Push branch to forge**
5. **Sync ArgoCD apps:**
   ```bash
   argocd app sync apps
   argocd app set torrent --revision feature/p6-kiwix
   argocd app sync torrent
   ```
6. **Verify transmission deployment:**
   ```bash
   kubectl --context=minikube-indri -n torrent get pods
   kubectl --context=minikube-indri -n torrent logs deployment/transmission
   ```
7. **Test transmission web UI:**
   - Open https://torrent.tail8d86e.ts.net in browser
   - Should see transmission web interface

### Phase C: Deploy Kiwix to Kubernetes

1. **Add kiwix manifests** to `argocd/manifests/kiwix/`
2. **Add ArgoCD Application** to `argocd/apps/kiwix.yaml`
3. **Push to forge**
4. **Sync ArgoCD:**
   ```bash
   argocd app set kiwix --revision feature/p6-kiwix
   argocd app sync kiwix
   ```
5. **Verify kiwix deployment:**
   ```bash
   kubectl --context=minikube-indri -n kiwix get pods
   kubectl --context=minikube-indri -n kiwix logs deployment/kiwix -c kiwix-serve
   kubectl --context=minikube-indri -n kiwix logs deployment/kiwix -c torrent-sync
   ```

### Phase D: Verification

1. **Test kiwix access:**
   ```bash
   curl -s https://kiwix.tail8d86e.ts.net/ | head -20
   ```
2. **Verify ZIM files are served:**
   - Open https://kiwix.tail8d86e.ts.net in browser
   - Should see library with existing ZIM archives
3. **Check transmission status via k8s:**
   ```bash
   kubectl --context=minikube-indri -n torrent exec deployment/transmission -- transmission-remote -l
   ```
4. **Verify torrent sync is working:**
   ```bash
   kubectl --context=minikube-indri -n kiwix logs deployment/kiwix -c torrent-sync
   ```
5. **Add a test torrent manually** via https://torrent.tail8d86e.ts.net to verify interactive use

### Phase E: Cutover

1. **Verify all services working correctly**
2. **Stop transmission on indri:**
   ```bash
   ssh indri 'brew services stop transmission-cli'
   ```
3. **Stop kiwix on indri:**
   ```bash
   ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.kiwix-serve.plist'
   ```
4. **Clear kiwix Tailscale serve entry:**
   ```bash
   ssh indri 'tailscale serve status --json'
   ssh indri 'tailscale serve clear svc:kiwix'
   ```
5. **Delete svc:kiwix device from Tailscale admin** (if needed to free hostname)
6. **Verify k8s services claim the hostnames:**
   ```bash
   curl -s https://kiwix.tail8d86e.ts.net/
   curl -s https://torrent.tail8d86e.ts.net/transmission/web/
   ```

### Phase F: Cleanup

1. **Remove indri transmission/kiwix from ansible:**
   - Remove `transmission` and `transmission_metrics` roles from `indri.yml`
   - Remove `kiwix` role from `indri.yml`
   - Remove `svc:kiwix` from `tailscale_serve`
   - Remove transmission/kiwix log collection from `alloy`
2. **Run ansible to clean up:**
   ```bash
   mise run provision-indri -- --tags tailscale-serve,alloy
   ```
3. **Merge PR** after all verification
4. **Reset ArgoCD to main:**
   ```bash
   argocd app set torrent --revision main
   argocd app sync torrent
   argocd app set kiwix --revision main
   argocd app sync kiwix
   ```

---

## Adding New ZIM Archives (Declarative)

To add a new ZIM archive via GitOps:

1. **Find torrent URL** on https://download.kiwix.org/zim/
2. **Add URL to ConfigMap** in `argocd/manifests/kiwix/configmap-zim-torrents.yaml`
3. **Commit and push** to feature branch
4. **Sync ArgoCD:**
   ```bash
   argocd app sync kiwix
   ```
5. **Wait for download** (check transmission at https://torrent.tail8d86e.ts.net)
6. **Kiwix restarts automatically** when ZIM watcher detects the new file (hourly)
   - Or manually: `kubectl rollout restart deployment/kiwix -n kiwix`

## Adding ZIM Archives (Manual/Interactive)

Alternatively, add a ZIM torrent manually:

1. **Open transmission web UI** at https://torrent.tail8d86e.ts.net
2. **Add torrent** via URL or file upload
3. **Wait for download** to complete
4. **Kiwix restarts automatically** when ZIM watcher detects the new file (hourly)
   - Or manually: `kubectl rollout restart deployment/kiwix -n kiwix`

Note: Manually added ZIM torrents are NOT tracked in git. If you want them to persist across cluster rebuilds, add them to the ConfigMap.

## Adding Non-ZIM Torrents

The transmission service is general-purpose:

1. **Open transmission web UI** at https://torrent.tail8d86e.ts.net
2. **Add any torrent** (Linux ISOs, etc.)
3. **Downloads go to** `/volume1/torrents/` on sifaka SMB share
4. **Access downloads** via SMB mount or sifaka's file browser

Non-ZIM downloads don't affect kiwix - it only serves `.zim` files.

---

## Rollback Plan

If migration fails:

1. **Stop k8s services:**
   ```bash
   argocd app delete kiwix --cascade
   argocd app delete torrent --cascade
   kubectl delete namespace kiwix
   kubectl delete namespace torrent
   kubectl delete pv torrents-smb-pv
   ```
2. **Restart indri services:**
   ```bash
   ssh indri 'brew services start transmission-cli'
   ssh indri 'launchctl load ~/Library/LaunchAgents/mcquack.eblume.kiwix-serve.plist'
   ```
3. **Re-enable Tailscale serve:**
   ```bash
   mise run provision-indri -- --tags tailscale-serve
   ```
4. **Verify access:**
   ```bash
   curl https://kiwix.tail8d86e.ts.net/
   ```

---

## Files Summary

### New Files

| Path | Purpose |
|------|---------|
| **Transmission (torrent namespace)** | |
| `argocd/apps/torrent.yaml` | ArgoCD Application for transmission |
| `argocd/apps/smb-csi.yaml` | ArgoCD Application for SMB CSI driver |
| `argocd/manifests/smb-csi/values.yaml` | SMB CSI driver Helm values |
| `argocd/manifests/torrent/pv-smb.yaml` | Shared SMB PersistentVolume |
| `argocd/manifests/torrent/secret-smb.yaml.tpl` | SMB credentials secret template |
| `argocd/manifests/torrent/pvc.yaml` | Transmission PVC |
| `argocd/manifests/torrent/deployment.yaml` | Transmission deployment |
| `argocd/manifests/torrent/service.yaml` | Transmission service |
| `argocd/manifests/torrent/ingress-tailscale.yaml` | Tailscale Ingress for torrent.tail8d86e.ts.net |
| `argocd/manifests/torrent/kustomization.yaml` | Kustomize configuration |
| **Kiwix (kiwix namespace)** | |
| `argocd/apps/kiwix.yaml` | ArgoCD Application for kiwix |
| `argocd/manifests/kiwix/pvc.yaml` | Kiwix PVC (references shared PV) |
| `argocd/manifests/kiwix/configmap-zim-torrents.yaml` | Declarative ZIM torrent URL list |
| `argocd/manifests/kiwix/configmap-sync-script.yaml` | ZIM torrent sync script |
| `argocd/manifests/kiwix/deployment.yaml` | Kiwix deployment with sync sidecar |
| `argocd/manifests/kiwix/service.yaml` | Kiwix service |
| `argocd/manifests/kiwix/ingress-tailscale.yaml` | Tailscale Ingress for kiwix.tail8d86e.ts.net |
| `argocd/manifests/kiwix/cronjob-zim-watcher.yaml` | ZIM watcher CronJob + RBAC |
| `argocd/manifests/kiwix/kustomization.yaml` | Kustomize configuration |

### Modified Files

| Path | Change |
|------|--------|
| `ansible/playbooks/indri.yml` | Remove transmission, transmission_metrics, kiwix roles |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Remove svc:kiwix |
| `ansible/roles/alloy/defaults/main.yml` | Remove transmission/kiwix log collection |

### Roles Kept (not deleted)

- `ansible/roles/transmission/` - Kept for reference
- `ansible/roles/transmission_metrics/` - Kept for reference
- `ansible/roles/kiwix/` - Kept for reference

---

## Verification Checklist

- [x] SMB share configured on sifaka (`/volume1/torrents`)
- [ ] Dedicated Synology user (`k8s-smb`) created for k8s access
- [ ] SMB CSI driver deployed to k8s
- [ ] Existing downloads copied to sifaka
- [ ] SMB credentials secret created in k8s (using `k8s-smb` user)
- [ ] Transmission pod running in k8s (`torrent` namespace)
- [ ] https://torrent.tail8d86e.ts.net accessible (web UI)
- [ ] Can add torrents manually via web UI
- [ ] Kiwix pod running in k8s (`kiwix` namespace)
- [ ] https://kiwix.tail8d86e.ts.net accessible
- [ ] All existing ZIM archives visible in kiwix
- [ ] Kiwix torrent-sync sidecar synced ZIMs to transmission
- [ ] ZIM watcher CronJob ran successfully
- [ ] Indri transmission stopped
- [ ] Indri kiwix stopped
- [ ] Tailscale hostname cutover complete (both services)
- [ ] Ansible playbook updated
- [ ] zk documentation updated
