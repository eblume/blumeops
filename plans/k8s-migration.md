# Blumeops Minikube Migration Plan

This plan details a phased migration of blumeops services from direct hosting on indri (Mac Mini M1) to a minikube cluster, while maintaining critical infrastructure services outside of Kubernetes.

## Architecture Overview

### Services Staying on Indri (Outside K8s)
| Service | Reason |
|---------|--------|
| **Zot Registry** (NEW) | Avoid circular dependency - k8s needs images to start |
| **Prometheus** | Observability backbone must survive k8s failures |
| **Loki** | Log aggregation backbone |
| **Borgmatic** | Backup system |
| **Grafana-alloy** | Metrics/logs collector on host |
| **Plex** | Until Jellyfin replacement |
| **Transmission** | Downloads for kiwix ZIM files |

### Services Moving to K8s
| Service | Complexity | Dependencies |
|---------|------------|--------------|
| Grafana | LOW | Phase 1 |
| Kiwix | LOW | Phase 1 |
| Miniflux | MEDIUM | PostgreSQL |
| devpi | MEDIUM | Registry |
| PostgreSQL | HIGH | Phase 1 |
| Forgejo | HIGH | PostgreSQL |
| Woodpecker CI | MEDIUM | Forgejo |

## Technical Decisions

### Container Registry: Zot
- OCI-native, lightweight
- Native support for proxying multiple registries (Docker Hub, GHCR, Quay)
- Built from source at `~/code/3rd/zot` (not in homebrew)
- Binary: `~/code/3rd/zot/bin/zot-darwin-arm64`
- Config: `~/.config/zot/config.json`
- Data: `~/zot/`

### Minikube Driver: Podman
- Rootless containers for better security
- Lighter than full VM (QEMU)
- Uses existing container ecosystem
- `minikube start --driver=podman --container-runtime=containerd`

### PostgreSQL: CloudNativePG Operator
- Production-grade operator
- Built-in backup/restore
- Prometheus metrics
- PITR support

### K8s Service Exposure: Tailscale Operator
- `loadBalancerClass: tailscale` on Services
- Automatic TLS and MagicDNS names
- ACL-controlled access

### LaunchAgent Requirements (Critical)
LaunchAgents do NOT get homebrew on PATH. All commands must use **absolute paths**:
- `/Users/erichblume/code/3rd/zot/bin/zot-darwin-arm64` for zot (built from source)
- `/opt/homebrew/opt/mise/bin/mise x --` for mise-managed tools
- `/opt/homebrew/opt/postgresql@18/bin/pg_dump` for postgres tools

This applies to all mcquack LaunchAgents (zot, devpi, kiwix, borgmatic, metrics collectors).
`brew services` handles this automatically but those aren't tracked in ansible.

### Backup Strategy

Borgmatic remains on indri (outside k8s), writing to sifaka NAS via SMB at `/Volumes/backups`. This ensures backups continue even if k8s is down.

| Service | Backup Approach |
|---------|-----------------|
| **Zot Registry** | No backup needed - pull-through cache is re-fetchable, private images rebuilt from source control |
| **Minikube** | No backup of cluster state - declarative manifests in git, can recreate |
| **PostgreSQL (k8s)** | CloudNativePG scheduled backups to sifaka (Phase 1) |
| **Grafana (k8s)** | Dashboards in ansible source control, no runtime backup needed |
| **Miniflux (k8s)** | Database backed up via CloudNativePG |
| **Forgejo (k8s)** | Git repos are distributed, config in ansible; data dir backed up via borgmatic before migration |
| **devpi (k8s)** | Private packages backed up, PyPI cache re-fetchable |
| **Kiwix (k8s)** | ZIM files re-downloadable via torrent, no backup needed |

**Borgmatic config changes:** None required for Phase 0. Future phases may add k8s PV paths if needed.

---

## Phase 0: Foundation

**Goal**: Container registry + minikube cluster without disrupting existing services

### Important: Tailscale Service Creation Order

> **WARNING**: You MUST create services in the Tailscale admin console BEFORE running `tailscale serve` commands via ansible. If you run `tailscale serve --service svc:foo` before the service exists in the admin console, the local config will be in a bad state.
>
> To fix a misconfigured service:
> ```bash
> tailscale serve --service svc:foo reset
> ```
> Then create the service in admin console and try again.

---

### Step 0.1: Update Pulumi ACLs (BEFORE Tailscale serve)

**Files to modify:**
- `pulumi/policy.hujson`

**Changes:**

1. Add new tag to `tagOwners` section (around line 104, after `"tag:feed"`):
```hujson
"tag:registry": ["autogroup:admin", "tag:blumeops"],
```

2. Add test cases to `tests` section:
   - Update Erich's accept list (around line 111) to include registry:
   ```hujson
   "accept": ["tag:grafana:443", "tag:kiwix:443", "tag:feed:443", "tag:loki:3100", "tag:pg:5432", "tag:homelab:22", "tag:registry:443"],
   ```
   - Update Allison's deny list (around line 117) to deny registry:
   ```hujson
   "deny": ["tag:grafana:443", "tag:loki:3100", "tag:nas:445", "tag:registry:443"],
   ```

**Note:**
- No member grant needed - admins have full access via wildcard, members don't need registry
- `tag:k8s` is added later in Phase 1 when the Tailscale Kubernetes Operator is deployed
- Zot supports htpasswd auth if we later need finer-grained control

**Testing:**
```bash
mise run tailnet-preview   # Review changes - should show new tag
mise run tailnet-up        # Apply changes
```

---

### Step 0.2: Create Tailscale Services in Admin Console (MANUAL)

> **CRITICAL**: Do this BEFORE running any ansible that calls `tailscale serve`

1. Go to https://login.tailscale.com/admin/services
2. Create service `registry` with:
   - Port: 443 (HTTPS)
   - Host: indri
3. Apply tag `tag:registry` to indri if not already tagged

**Verification:**
```bash
# Service should appear (even if not yet serving)
tailscale status | grep registry
```

---

### Step 0.3: Create Zot Registry Ansible Role

**Note:** Zot is NOT in homebrew (no formula or tap). Clone to `~/code/3rd/` on indri and build from source (requires Go).

**Prerequisites on indri (ALREADY COMPLETED):**
```bash
# Clone zot from forge mirror (use localhost:3001 - hairpinning doesn't work on indri)
ssh indri 'git clone http://localhost:3001/eblume/zot.git ~/code/3rd/zot'

# Set up Go via mise (creates mise.toml in repo directory)
ssh indri 'cd ~/code/3rd/zot && mise use go@1.25'

# Build (creates bin/zot-darwin-arm64, ~183MB)
ssh indri 'cd ~/code/3rd/zot && mise x -- make binary'

# Verify binary exists
ssh indri 'ls -la ~/code/3rd/zot/bin/zot-darwin-arm64'
```

**Build verified:** Binary at `~/code/3rd/zot/bin/zot-darwin-arm64` (183MB, ARM64 native).

**New files:**
```
ansible/roles/zot/
├── defaults/main.yml
├── tasks/main.yml
├── templates/
│   ├── config.json.j2
│   └── zot.plist.j2
└── handlers/main.yml
```

**Key configuration (defaults/main.yml):**
```yaml
zot_repo_dir: "/Users/erichblume/code/3rd/zot"
zot_binary: "{{ zot_repo_dir }}/bin/zot-darwin-arm64"
zot_data_dir: "/Users/erichblume/zot"
zot_config_dir: "/Users/erichblume/.config/zot"
zot_port: 5000
zot_log_dir: "/Users/erichblume/Library/Logs"

# Pull-through cache registries (on-demand sync)
zot_sync_registries:
  - name: docker.io
    url: https://registry-1.docker.io
  - name: ghcr.io
    url: https://ghcr.io
  - name: quay.io
    url: https://quay.io
```

**Zot config.json template** (key sections):
```json
{
  "storage": {
    "rootDirectory": "/Users/erichblume/zot"
  },
  "http": {
    "address": "0.0.0.0",
    "port": "5000"
  },
  "extensions": {
    "sync": {
      "enable": true,
      "registries": [
        {
          "urls": ["https://registry-1.docker.io"],
          "content": [{"prefix": "**"}],
          "onDemand": true,
          "tlsVerify": true
        },
        {
          "urls": ["https://ghcr.io"],
          "content": [{"prefix": "**"}],
          "onDemand": true,
          "tlsVerify": true
        },
        {
          "urls": ["https://quay.io"],
          "content": [{"prefix": "**"}],
          "onDemand": true,
          "tlsVerify": true
        }
      ]
    }
  }
}
```

**Two modes of operation:**

1. **Pull-through cache** (automatic): When you pull `registry.tail8d86e.ts.net/docker.io/library/nginx:latest`, Zot fetches from Docker Hub and caches locally. Subsequent pulls are local.

2. **Private images** (manual push): Push your own images to any path NOT matching a sync prefix:
   ```bash
   # From gilbert (after building)
   podman push myapp:v1 registry.tail8d86e.ts.net/blumeops/myapp:v1
   ```

**Namespace convention:**
- `registry.tail8d86e.ts.net/docker.io/*` → cached from Docker Hub
- `registry.tail8d86e.ts.net/ghcr.io/*` → cached from GHCR
- `registry.tail8d86e.ts.net/quay.io/*` → cached from Quay
- `registry.tail8d86e.ts.net/blumeops/*` → private images (built by you/Woodpecker)

**LaunchAgent template (zot.plist.j2):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>mcquack.eblume.zot</string>
    <key>ProgramArguments</key>
    <array>
        <!-- ABSOLUTE PATH to built binary in ~/code/3rd/zot -->
        <string>{{ zot_binary }}</string>
        <string>serve</string>
        <string>{{ zot_config_dir }}/config.json</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>{{ zot_log_dir }}/mcquack.zot.out.log</string>
    <key>StandardErrorPath</key>
    <string>{{ zot_log_dir }}/mcquack.zot.err.log</string>
</dict>
</plist>
```

**Handlers (handlers/main.yml):**
```yaml
- name: Restart zot
  ansible.builtin.command:
    cmd: launchctl kickstart -k gui/$(id -u)/mcquack.eblume.zot
  listen: restart zot
```

**Tasks should notify handler on config change:**
```yaml
- name: Deploy zot config
  ansible.builtin.template:
    src: config.json.j2
    dest: "{{ zot_config_dir }}/config.json"
  notify: restart zot
```

**Testing (after deploying role):**
```bash
# Check LaunchAgent is running
ssh indri 'launchctl list | grep zot'

# Check zot is responding
ssh indri 'curl -s http://localhost:5000/v2/_catalog'
# Expected: {"repositories":[]}

# Check logs for errors
ssh indri 'tail -20 ~/Library/Logs/mcquack.zot.err.log'

# Test pull-through cache via curl (podman not installed until Step 0.8)
ssh indri 'curl -s http://localhost:5000/v2/docker.io/library/alpine/manifests/latest -H "Accept: application/vnd.oci.image.manifest.v1+json"'
# Should return manifest JSON (triggers cache fetch from Docker Hub)
ssh indri 'curl -s http://localhost:5000/v2/_catalog'
# Expected: {"repositories":["docker.io/library/alpine"]}
```

---

### Step 0.4: Add Zot to Tailscale Serve

**Files to modify:**
- `ansible/roles/tailscale_serve/defaults/main.yml`

**Changes:**
```yaml
# Add to tailscale_serve_services list
- name: svc:registry
  https:
    port: 443
    upstream: http://localhost:5000
```

**Testing:**
```bash
# Deploy tailscale serve config
mise run provision-indri -- --tags tailscale-serve

# Verify from gilbert (not indri - hairpinning doesn't work)
curl -s https://registry.tail8d86e.ts.net/v2/_catalog
# Expected: {"repositories":["docker.io/library/alpine"]} (from Step 0.3 test)

# Test private image push from gilbert
podman pull alpine:latest
podman tag alpine:latest registry.tail8d86e.ts.net/blumeops/test:v1
podman push registry.tail8d86e.ts.net/blumeops/test:v1
curl -s https://registry.tail8d86e.ts.net/v2/_catalog
# Expected: {"repositories":["blumeops/test","docker.io/library/alpine"]}
```

---

### Step 0.5: Create Zot Metrics Role

**New files:**
```
ansible/roles/zot_metrics/
├── defaults/main.yml
├── tasks/main.yml
├── templates/
│   ├── zot-metrics.sh.j2
│   └── zot-metrics.plist.j2
└── handlers/main.yml
```

**Metrics script pattern (zot-metrics.sh.j2):**
```bash
#!/bin/bash
# Collect Zot registry metrics for Prometheus textfile collector
set -euo pipefail

METRICS_FILE="/opt/homebrew/var/node_exporter/textfile/zot.prom"
TEMP_FILE="${METRICS_FILE}.tmp"

# Check if zot is up
if curl -sf http://localhost:5000/v2/_catalog > /dev/null 2>&1; then
    echo "zot_up 1" > "$TEMP_FILE"
else
    echo "zot_up 0" > "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$METRICS_FILE"
```

**Note:** Start with just `zot_up` for now. Additional metrics (storage usage, cache stats) can be added later after reviewing zot's metrics endpoint.

**Testing:**
```bash
# Deploy metrics role
mise run provision-indri -- --tags zot_metrics

# Check metrics file exists and is updated
ssh indri 'cat /opt/homebrew/var/node_exporter/textfile/zot.prom'
# Expected: zot_up 1

# Verify metrics appear in Prometheus (after a scrape cycle)
curl -s "http://indri:9090/api/v1/query?query=zot_up" | jq '.data.result[0].value[1]'
# Expected: "1"
```

---

### Step 0.6: Add Zot Log Collection to Alloy

**Files to modify:**
- `ansible/roles/alloy/templates/config.alloy.j2`

**Changes:**
Add to the mcquack services log collection section:
```alloy
// Zot registry logs
local.file_match "zot_logs" {
  path_targets = [
    {__path__ = "/Users/erichblume/Library/Logs/mcquack.zot.out.log", service = "zot", stream = "stdout"},
    {__path__ = "/Users/erichblume/Library/Logs/mcquack.zot.err.log", service = "zot", stream = "stderr"},
  ]
}

loki.source.file "zot_logs" {
  targets    = local.file_match.zot_logs.targets
  forward_to = [loki.write.local.receiver]
}
```

**Testing:**
```bash
# Deploy alloy config (handler restarts alloy automatically if config changed)
mise run provision-indri -- --tags alloy

# Wait a minute, then check Loki for zot logs
# In Grafana Explore, query: {service="zot"}
```

---

### Step 0.7: Update indri-services-check Script

**Files to modify:**
- `mise-tasks/indri-services-check`

**Changes to add:**
```bash
# Add after existing service checks (around line 55)
check_service "zot" "ssh indri 'launchctl list | grep zot | grep -v \"^-\"'"
check_service "zot-metrics" "ssh indri 'launchctl list | grep zot-metrics | grep -v \"^-\"'"

# Add to HTTP endpoints section (around line 65)
check_http "Zot Registry" "http://indri:5000/v2/_catalog"

# Add metrics file check
check_service "Zot metrics" "ssh indri 'test -f /opt/homebrew/var/node_exporter/textfile/zot.prom'"
```

**Testing:**
```bash
# Run the health check
mise run indri-services-check

# Expected output includes:
# zot...               OK
# zot-metrics...       OK
# Zot Registry...      OK
# Zot metrics...       OK
```

---

### Step 0.8: Install and Configure Podman on Indri

**New files:**
```
ansible/roles/podman/
├── tasks/main.yml
└── handlers/main.yml
```

**Tasks (tasks/main.yml):**
```yaml
- name: Install podman via homebrew
  community.general.homebrew:
    name: podman
    state: present

- name: Initialize podman machine (if not exists)
  ansible.builtin.command:
    cmd: podman machine init --cpus 4 --memory 8192 --disk-size 220
  register: podman_init
  changed_when: podman_init.rc == 0
  failed_when: podman_init.rc not in [0, 125]  # 125 = already exists

- name: Start podman machine
  ansible.builtin.command:
    cmd: podman machine start
  register: podman_start
  changed_when: "'started successfully' in podman_start.stdout"
  failed_when: podman_start.rc not in [0, 125]  # 125 = already running
```

**Testing:**
```bash
# Deploy podman role
mise run provision-indri -- --tags podman

# Verify podman is working
ssh indri 'podman info'
ssh indri 'podman run --rm hello-world'
```

---

### Step 0.9: Install and Configure Minikube

**New files:**
```
ansible/roles/minikube/
├── defaults/main.yml
├── tasks/main.yml
└── handlers/main.yml
```

**Defaults:**
```yaml
minikube_cpus: 4
minikube_memory: 8192
minikube_disk_size: "200g"
minikube_driver: podman
minikube_container_runtime: containerd
```

**Note on storage:** The disk-size is for node-local storage only (container images, emptyDir, local PVs). Pods can also mount external storage:
- **hostPath** - indri filesystem (e.g., `~/transmission/` for kiwix ZIM files)
- **NFS** - sifaka volumes (Synology supports NFS natively, easiest for k8s)
- **SMB/CIFS** - requires csi-driver-smb; sifaka currently uses SMB for desktop mounts

**Tasks:**
```yaml
- name: Install minikube via homebrew
  community.general.homebrew:
    name: minikube
    state: present

- name: Check if minikube cluster exists
  ansible.builtin.command:
    cmd: minikube status --format='{{.Host}}'
  register: minikube_status
  changed_when: false
  failed_when: false

- name: Start minikube cluster
  ansible.builtin.command:
    cmd: >
      minikube start
      --driver={{ minikube_driver }}
      --container-runtime={{ minikube_container_runtime }}
      --cpus={{ minikube_cpus }}
      --memory={{ minikube_memory }}
      --disk-size={{ minikube_disk_size }}
  when: minikube_status.rc != 0 or 'Running' not in minikube_status.stdout
```

**Testing:**
```bash
# Deploy minikube role
mise run provision-indri -- --tags minikube

# Verify cluster is running
ssh indri 'minikube status'
# Expected: host: Running, kubelet: Running, apiserver: Running

# Test kubectl access from indri
ssh indri 'kubectl get nodes'
# Expected: minikube   Ready    control-plane   ...
```

---

### Step 0.10: Configure Kubeconfig on Gilbert

**No special Tailscale service needed** - admin users already have full access to indri via the `autogroup:admin → * → *` grant. Gilbert can reach the K8s API server on indri directly.

**Manual steps** (kubeconfig management is complex with work configs):

```bash
# Copy minikube kubeconfig from indri
ssh indri 'cat ~/.kube/config' > /tmp/minikube-config.yaml

# IMPORTANT: Replace localhost/127.0.0.1 with indri's hostname
# Minikube's kubeconfig points to localhost since it runs locally on indri
sed -i '' 's|https://127.0.0.1:|https://indri:|g' /tmp/minikube-config.yaml
sed -i '' 's|https://localhost:|https://indri:|g' /tmp/minikube-config.yaml

# Merge into local kubeconfig (careful not to overwrite work configs!)
# Option A: Use KUBECONFIG env var to include multiple files
export KUBECONFIG=~/.kube/config:~/.kube/minikube.yaml

# Option B: Manually merge contexts
kubectl config --kubeconfig=/tmp/minikube-config.yaml view --flatten > ~/.kube/minikube.yaml

# Set minikube context
kubectl config use-context minikube

# Verify connection from gilbert
kubectl get nodes
```

**Testing:**
```bash
# From gilbert, verify k8s access
kubectl cluster-info
kubectl get namespaces

# Verify k9s can connect
k9s
# Should show the minikube cluster
```

---

### Step 0.11: Add Minikube to indri-services-check

**Files to modify:**
- `mise-tasks/indri-services-check`

**Changes:**
```bash
# Add new section for Kubernetes
echo ""
echo "Kubernetes cluster:"
check_service "minikube" "ssh indri 'minikube status --format={{.Host}} | grep -q Running'"
check_service "k8s-apiserver" "ssh indri 'kubectl get --raw /healthz'"
```

**Testing:**
```bash
mise run indri-services-check

# Expected output includes:
# Kubernetes cluster:
# minikube...          OK
# k8s-apiserver...     OK
```

---

### Step 0.12: Create Zettelkasten Documentation

**New files:**
- `~/code/personal/zk/zot.md`
- `~/code/personal/zk/minikube.md`

**Template for zot.md:**
```markdown
---
id: zot
aliases:
  - zot
  - container-registry
tags:
  - blumeops
---

# Zot Registry Management Log

Zot is an OCI-native container registry running on Indri, providing:
1. Pull-through cache for Docker Hub, GHCR, Quay (avoids rate limits)
2. Private image storage for custom-built containers

## Service Details

- URL: https://registry.tail8d86e.ts.net
- Local port: 5000
- Data directory: ~/zot
- Config: ~/.config/zot/config.json
- Managed via: mcquack LaunchAgent

## Namespace Convention

| Path | Source |
|------|--------|
| `registry.../docker.io/*` | Cached from Docker Hub |
| `registry.../ghcr.io/*` | Cached from GHCR |
| `registry.../quay.io/*` | Cached from Quay |
| `registry.../blumeops/*` | Private images (yours) |

## Useful Commands

\`\`\`bash
# List all images
curl -s http://localhost:5000/v2/_catalog | jq

# Pull via cache (from indri or k8s)
podman pull localhost:5000/docker.io/library/nginx:latest

# Build and push private image (from gilbert)
podman build -t registry.tail8d86e.ts.net/blumeops/myapp:v1 .
podman push registry.tail8d86e.ts.net/blumeops/myapp:v1

# Check service status
launchctl list | grep zot

# View logs
tail -f ~/Library/Logs/mcquack.zot.err.log
\`\`\`

## Log

### [DATE]
- Initial setup for k8s migration Phase 0
```

---

### Step 0.13: Update Main Playbook

**Files to modify:**
- `ansible/playbooks/indri.yml`

**Changes:**
```yaml
# Add new roles to the roles list
- role: podman
  tags: podman
- role: zot
  tags: zot
- role: zot_metrics
  tags: zot_metrics
- role: minikube
  tags: minikube
```

---

### Phase 0 Verification Checklist

Run after completing all steps:

```bash
# 1. Full service health check
mise run indri-services-check
# All services should show OK, including new ones

# 2. Registry functionality - pull-through cache
ssh indri 'podman pull localhost:5000/docker.io/library/alpine:latest'
curl -s https://registry.tail8d86e.ts.net/v2/_catalog
# Expected: {"repositories":["docker.io/library/alpine"]}

# 3. Registry functionality - private image push (from gilbert)
podman pull alpine:latest
podman tag alpine:latest registry.tail8d86e.ts.net/blumeops/test:v1
podman push registry.tail8d86e.ts.net/blumeops/test:v1
curl -s https://registry.tail8d86e.ts.net/v2/_catalog
# Expected: {"repositories":["blumeops/test","docker.io/library/alpine"]}

# 4. Kubernetes cluster
ssh indri 'minikube status'
ssh indri 'kubectl get nodes'
kubectl get nodes  # from gilbert

# 5. Metrics in Prometheus
curl -s "http://indri:9090/api/v1/query?query=zot_up"
# Expected: value = 1

# 6. Logs in Loki
# In Grafana Explore: {service="zot"}
# Should see zot log entries

# 7. k9s from gilbert
k9s
# Should connect and show minikube cluster
```

---

### Phase 0 Rollback

If something goes wrong:

```bash
# Stop and remove minikube
ssh indri 'minikube stop && minikube delete'

# Stop and remove zot
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.zot.plist'
ssh indri 'rm ~/Library/LaunchAgents/mcquack.eblume.zot.plist'

# Remove podman machine
ssh indri 'podman machine stop && podman machine rm'

# Remove from tailscale serve
ssh indri 'tailscale serve --service svc:registry reset'

# Remove tags from Pulumi (revert policy.hujson changes)
mise run tailnet-up

# Revert ansible playbook changes
git checkout ansible/playbooks/indri.yml
git checkout ansible/roles/tailscale_serve/defaults/main.yml
git checkout ansible/roles/alloy/templates/config.alloy.j2

# Remove new roles
rm -rf ansible/roles/{zot,zot_metrics,podman,minikube}

# Remove zk cards
rm ~/code/personal/zk/{zot,minikube}.md
```

---

### Phase 0 Follow-up: Grafana Dashboards

After Phase 0 is running and stable, create monitoring dashboards:

**Zot Dashboard** (`ansible/roles/grafana/files/dashboards/zot.json`):
1. Check what metrics zot exposes: `ssh indri 'curl -s http://localhost:5000/metrics'`
2. Review community dashboards for inspiration (copy permitted if license allows)
3. Create dashboard with available metrics (at minimum: `zot_up`)

**Minikube Dashboard** (`ansible/roles/grafana/files/dashboards/minikube.json`):
1. Deploy kube-state-metrics if needed for additional cluster metrics
2. Review what Prometheus can scrape from the cluster
3. Review community dashboards for inspiration (copy permitted if license allows)
4. Create dashboard with relevant panels (node usage, pod counts, etc.)

---

### New Files Summary

| File | Purpose |
|------|---------|
| `ansible/roles/zot/` | Zot registry deployment |
| `ansible/roles/zot_metrics/` | Metrics collection for Zot |
| `ansible/roles/podman/` | Podman installation and setup |
| `ansible/roles/minikube/` | Minikube cluster setup |
| `~/code/personal/zk/zot.md` | Zot management documentation |
| `~/code/personal/zk/minikube.md` | Minikube management documentation |

### Modified Files Summary

| File | Changes |
|------|---------|
| `pulumi/policy.hujson` | Add tag:registry |
| `ansible/playbooks/indri.yml` | Add new roles |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Add svc:registry |
| `ansible/roles/alloy/templates/config.alloy.j2` | Add zot log collection |
| `mise-tasks/indri-services-check` | Add zot and k8s checks |

---

## Phase 1: Kubernetes Infrastructure

**Goal**: Tailscale operator + CloudNativePG operator

### Steps

1. **Update Pulumi ACLs for k8s workloads**

   Add `tag:k8s` to `pulumi/policy.hujson` - this tag is for k8s workloads that need to access other services (e.g., Woodpecker CI pushing to registry).

   **Changes to tagOwners:**
   ```hujson
   "tag:k8s": ["autogroup:admin", "tag:blumeops"],
   ```

   **Add grant for k8s→registry access:**
   ```hujson
   // k8s workloads (e.g., Woodpecker CI) can push/pull from registry
   {
   	"src": ["tag:k8s"],
   	"dst": ["tag:registry"],
   	"ip":  ["tcp:443"],
   },
   ```

   **Add test case:**
   ```hujson
   {
   	"src":    "tag:k8s",
   	"accept": ["tag:registry:443"],
   },
   ```

   ```bash
   mise run tailnet-preview && mise run tailnet-up
   ```

2. **Create Tailscale OAuth client**
   - Scopes: Devices Core, Auth Keys, Services write
   - Tag: `tag:k8s-operator`
   - Store in 1Password

3. **Deploy Tailscale Kubernetes Operator**
   ```bash
   helm repo add tailscale https://pkgs.tailscale.com/helmcharts
   helm install tailscale-operator tailscale/tailscale-operator \
     --namespace tailscale-system --create-namespace \
     --set oauth.clientId=$CLIENT_ID \
     --set oauth.clientSecret=$CLIENT_SECRET
   ```

4. **Deploy CloudNativePG operator**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml
   ```

5. **Create PostgreSQL cluster**
   ```yaml
   apiVersion: postgresql.cnpg.io/v1
   kind: Cluster
   metadata:
     name: blumeops-pg
     namespace: databases
   spec:
     instances: 1
     storage:
       size: 10Gi
       storageClass: standard
     monitoring:
       enablePodMonitor: true
   ```

6. **Update Alloy config**
   - Add kubernetes_sd_configs for k8s metrics
   - Scrape operator metrics

### New Files
- `ansible/k8s/operators/` - Operator manifests
- `ansible/k8s/databases/` - PostgreSQL cluster

### Verification
```bash
kubectl get pods -n tailscale-system
kubectl get pods -n cnpg-system
kubectl get cluster -n databases
```

---

## Phase 2: Grafana Migration (Pilot)

**Goal**: Migrate Grafana as lowest-risk pilot service

### Steps

1. **Deploy Grafana via Helm**
   - Copy datasource config from existing role
   - Copy dashboards from `ansible/roles/grafana/files/dashboards/`
   - Point to indri Prometheus/Loki (http://indri:9090, http://indri:3100)

2. **Configure Tailscale LoadBalancer**
   ```yaml
   service:
     type: LoadBalancer
     loadBalancerClass: tailscale
   ```

3. **Verify all dashboards work**

4. **Update tailscale_serve** - remove grafana entry

5. **Stop brew grafana**: `brew services stop grafana`

### Verification
- https://grafana.tail8d86e.ts.net loads
- All dashboards functional

---

## Phase 3: PostgreSQL Migration

**Goal**: Migrate miniflux database to CloudNativePG

### Steps

1. **Create databases and users in k8s PostgreSQL**
   - miniflux database/user
   - borgmatic read-only user

2. **Export from brew PostgreSQL**
   ```bash
   pg_dump -h localhost -U miniflux miniflux > miniflux_backup.sql
   ```

3. **Expose k8s PostgreSQL via Tailscale**
   - Service with `loadBalancerClass: tailscale`
   - Tag: `svc:pg-k8s`

4. **Import data**
   ```bash
   psql -h pg-k8s.tail8d86e.ts.net -U miniflux miniflux < miniflux_backup.sql
   ```

5. **Update borgmatic config**
   - Change hostname to k8s PostgreSQL

6. **Verify data integrity**

### Rollback
Keep brew PostgreSQL running until Phase 4 verified

---

## Phase 4: Miniflux Migration

**Goal**: Migrate Miniflux to k8s

### Steps

1. **Deploy Miniflux**
   ```yaml
   image: ghcr.io/miniflux/miniflux:latest
   env:
     DATABASE_URL: from secret
     RUN_MIGRATIONS: "1"
   ```

2. **Configure Tailscale LoadBalancer** - tag: `svc:feed`

3. **Update Alloy log collection** - add k8s namespace

4. **Verify**: login, feeds refresh, API works

5. **Stop brew miniflux**: `brew services stop miniflux`

---

## Phase 5: devpi Migration

**Goal**: Migrate devpi to k8s

### Steps

1. **Build devpi container**
   - Dockerfile with devpi-server + devpi-web
   - Push to local Zot registry

2. **Deploy as StatefulSet**
   - PVC for data (50Gi)
   - Migrate existing data (excluding PyPI cache)

3. **Configure Tailscale LoadBalancer** - tag: `svc:pypi`

4. **Update pip.conf on gilbert**

5. **Stop mcquack devpi**

---

## Phase 6: Kiwix Migration

**Goal**: Migrate kiwix-serve to k8s

### Steps

1. **Create NFS/hostPath PV for ZIM files**
   - Point to transmission download directory
   - ReadOnlyMany access

2. **Deploy Kiwix**
   ```yaml
   image: ghcr.io/kiwix/kiwix-serve:3.8.1
   args: ["/data/*.zim"]
   ```

3. **Configure Tailscale LoadBalancer** - tag: `svc:kiwix`

4. **Stop mcquack kiwix-serve**

---

## Phase 7: Forgejo Migration (Highest Risk)

**Goal**: Migrate Forgejo to k8s

### Pre-Migration Checklist
- [ ] Full borgmatic backup verified
- [ ] Manual backup of `/opt/homebrew/var/forgejo`
- [ ] Document SSH keys and webhooks

### Steps

1. **Deploy Forgejo via Helm**
   ```bash
   helm install forgejo forgejo/forgejo \
     --namespace forgejo --create-namespace
   ```

2. **Migrate data**
   - Stop brew forgejo
   - Copy data to PVC
   - Start k8s forgejo

3. **Configure Tailscale services**
   - HTTPS 443 via LoadBalancer
   - SSH port 22 (TCP proxy)

4. **Verify all repositories accessible**

### Rollback
Restore brew forgejo and tailscale serve config

---

## Phase 8: CI/CD (Woodpecker)

**Goal**: Deploy Woodpecker CI integrated with Forgejo

### Steps

1. **Create Forgejo OAuth application**
   - Callback: https://ci.tail8d86e.ts.net/authorize
   - Store in 1Password

2. **Deploy Woodpecker Server + Agent**

3. **Configure Tailscale LoadBalancer** - tag: `svc:ci`

4. **Test pipeline** - create `.woodpecker.yaml` in test repo

---

## Phase 9: Cleanup

**Goal**: Remove deprecated services, harden system

### Steps

1. **Stop/remove unused brew services**
   - postgresql@18, grafana, miniflux, forgejo

2. **Update ansible playbook**
   - Remove migrated service roles
   - Add k8s deployment references

3. **Configure Velero backups** (optional)
   - Install with MinIO on sifaka
   - Schedule daily cluster backups

4. **Update zk documentation**
   - New architecture
   - Runbooks
   - DR procedures

---

## Critical Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/indri.yml` | Main playbook - add k8s roles, remove migrated services |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Transition services to Tailscale operator |
| `pulumi/policy.hujson` | Add tags: k8s, registry, ci |
| `ansible/roles/borgmatic/defaults/main.yml` | Update PostgreSQL endpoint |
| `mise-tasks/indri-services-check` | Add k8s health checks |

## New Directory Structure

```
ansible/
  k8s/
    operators/
      tailscale-operator.yaml
      cloudnative-pg.yaml
    databases/
      blumeops-pg.yaml
    apps/
      grafana/
      miniflux/
      forgejo/
      devpi/
      kiwix/
      woodpecker/
  roles/
    zot/           # NEW
    podman/        # NEW
    minikube/      # NEW
```

## Risk Mitigation

- **Circular dependency prevention**: Zot registry runs outside k8s
- **Observability**: Prometheus/Loki stay on indri
- **Data loss prevention**: borgmatic + manual backups before each phase
- **Recovery**: Can manually push images, restore from backups

## Container Images (All ARM64)

| Service | Image |
|---------|-------|
| Miniflux | `ghcr.io/miniflux/miniflux:latest` |
| Forgejo | `codeberg.org/forgejo/forgejo:10` |
| Grafana | `grafana/grafana:latest` |
| Kiwix | `ghcr.io/kiwix/kiwix-serve:3.8.1` |
| Woodpecker | `woodpeckerci/woodpecker-server` |

Note: Zot runs as a native binary on indri (built from source at `~/code/3rd/zot`), not as a container.

---

## Plan Completion

When all phases are complete and verified:

```bash
# Move plan to completed directory with completion date
git mv plans/k8s-migration.md plans/completed/k8s-migration.$(date +%Y-%m-%d).md
git commit -m "Complete k8s migration plan"
```
