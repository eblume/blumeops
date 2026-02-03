---
id: minikube
aliases:
  - kubernetes
  - k8s
tags:
  - blumeops
---

# Minikube Management Log

Minikube provides a single-node Kubernetes cluster on Indri for running containerized services.

## Cluster Details

- Driver: **docker** (runs as container inside Docker Desktop)
- Container runtime: docker
- Kubernetes version: v1.34.0
- Resources: 6 CPUs, 11GB RAM (leaves 1GB for Docker Desktop overhead), 200GB disk
- API server: https://k8s.tail8d86e.ts.net (Tailscale service with TCP passthrough)
- Internal port: dynamic (currently 50820 - Docker maps random host port to container's 6443)

**Prerequisites:** Docker Desktop must be installed and running with at least 12GB memory allocated.

## Remote Access from Gilbert

Run `mise run ensure-minikube-indri-kubectl-config` to set up kubectl access. This script:
1. Fetches certificates from indri via SSH
2. Creates kubeconfig at `~/.kube/minikube-indri/config.yml`

**Fish abbreviations** (in `~/.config/fish/config.fish`):
- `ki` -> `kubectl --context=minikube-indri`
- `k9i` -> `k9s --context=minikube-indri`
- `k9` -> `k9s`

```bash
# Quick access via abbreviations
ki get nodes
k9i

# Or explicitly set context
kubectl config use-context minikube-indri
kubectl get nodes
```

## Volume Mounting (for P6 kiwix/transmission)

**Direct NFS from pods to sifaka** - tested and working.

Docker NATs outbound traffic through indri's LAN IP (192.168.1.50). Sifaka's NFS exports allow:
- `192.168.1.0/24` - Docker containers via indri NAT
- `100.64.0.0/10` - Tailscale clients

Pods mount NFS directly:
```yaml
volumes:
  - name: torrents
    nfs:
      server: sifaka
      path: /volume1/torrents
```

No LaunchAgents, no `minikube mount`, no hostPath complexity needed.

## Useful Commands (on indri)

```bash
# Cluster status
minikube status

# Start/stop cluster
minikube start
minikube stop

# Access dashboard
minikube dashboard

# SSH into node
minikube ssh

# View logs
minikube logs

# Get API server URL (shows current port)
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"
```

## Registry Mirror (Zot)

Containerd is configured to use [[zot]] on indri as a pull-through cache for container images. This is managed by the ansible `minikube` role.

Config location: `/etc/containerd/certs.d/<registry>/hosts.toml` (inside minikube container)

With docker driver, uses `host.minikube.internal:5050` to reach zot on the host.

Mirrors configured for:
- `registry.ops.eblu.me` (private images)
- `docker.io`
- `ghcr.io`
- `quay.io`

To verify the mirror is working:
```bash
# Check zot's cached images
curl -s http://localhost:5050/v2/_catalog | jq
```

## Log

### 2026-01-21 (Docker Driver Migration)
- **Migrated from qemu2 to docker driver** (Phase 5.1)
- qemu2 had Tailscale TCP proxy issue (TLS handshake timeout to VM IP)
- docker driver puts API server on localhost, which Tailscale serve handles correctly
- Removed socket_vmnet, qemu dependencies
- Removed NFS/minikube-mount LaunchAgents (will re-add NFS for P6 with simpler hostPath approach)
- API server port is now dynamic (Docker assigns random host port)
- Ansible role updated to query port and configure tailscale serve accordingly
- Created `mise run ensure-minikube-indri-kubectl-config` for workstation setup

### 2026-01-21 (QEMU2 Migration - superseded)
- Migrated from podman to qemu2 driver
- Podman driver had fundamental limitations preventing volume mounts
- qemu2 created actual VM with full kernel capabilities
- Volume mounting solution: NFS on host + minikube mount passthrough
- **Issue discovered:** Tailscale TCP proxy to VM IP (192.168.105.2:6443) fails with TLS timeout

### 2026-01-19
- Configured CRI-O registry mirror to use zot as pull-through cache
- Added ansible automation to apply mirror config on provisioning
- Fixed ansible hanging: `minikube ssh` with piped stdin requires `--native-ssh=false`

### 2026-01-18
- Initial cluster setup for k8s migration Phase 0
- Configured for remote access with --apiserver-names=indri
- 1Password credential integration for kubectl from gilbert
- Exposed as Tailscale service `k8s.tail8d86e.ts.net` with TCP passthrough
