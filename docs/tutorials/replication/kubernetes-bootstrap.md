---
title: Kubernetes Bootstrap
modified: 2026-10-22
last-reviewed: 2026-10-22
tags:
  - tutorials
  - replication
  - kubernetes
---

# Bootstrapping Kubernetes

> **Audiences:** Replicator

This tutorial walks through setting up a Kubernetes cluster for your homelab, making it accessible via Tailscale.

## Choosing a Distribution

For homelab use, lightweight distributions work well:

| Distribution | Best For | BlumeOps Uses |
|--------------|----------|---------------|
| **k3s** | Single-node, Linux | Yes (ringtail) |
| **Minikube** | Single-node, macOS | - |
| **kind** | Local development | - |
| **kubeadm** | Multi-node clusters | - |

This tutorial uses k3s, the distribution BlumeOps runs (single node, on [[ringtail]]). The principles apply broadly — minikube, kind, and other distributions differ only in installation and API-server details.

For BlumeOps specifics, see [[cluster|Cluster Reference]].

## Step 1: Install k3s

On your Linux server:

```bash
curl -sfL https://get.k3s.io | sh -
```

The installer starts a single-node server: the API server listens on
`0.0.0.0:6443`, and a local kubeconfig lands at `/etc/rancher/k3s/k3s.yaml`.

## Step 2: Verify the Cluster

```bash
sudo k3s kubectl get nodes
# Should show your node as Ready

sudo k3s kubectl get pods -A
# Should show system pods running
```

## Step 3: Expose via Tailscale

k3s's API server already binds all interfaces, so on the tailnet the cluster
is reachable at `https://<your-host>.<your-tailnet>.ts.net:6443` with no extra
exposure step.

For ingress to workloads, install the Tailscale Kubernetes operator, which
manages ingress automatically. BlumeOps uses it ([[tailscale-operator]]); see
[[routing|Routing Reference]] for how clients reach the API server over the
tailnet (there is no dedicated hostname for it).

## Step 4: Configure Remote Access

On your workstation, fetch the kubeconfig from the server:

```bash
# Copy the kubeconfig
scp server:/etc/rancher/k3s/k3s.yaml ~/.kube/cluster.yaml

# Point it at the tailnet address
# server: https://127.0.0.1:6443  ->  https://<your-host>.<your-tailnet>.ts.net:6443
```

The CA cert, client certificate, and key are embedded in the kubeconfig, so no
separate credential copying is needed.

```bash
# Test
KUBECONFIG=~/.kube/cluster.yaml kubectl get nodes
```

## Step 5: Storage Configuration

For persistent workloads, configure storage:

### Local Path (k3s Default)

k3s ships the local-path provisioner with `local-path` as the default storage
class — node-local storage for stateful workloads:

```bash
sudo k3s kubectl get storageclass
# local-path ... default
```

### NFS for Shared Storage

If you have a NAS on your tailnet, create a static PersistentVolume and PersistentVolumeClaim pair:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: media-nfs-pv
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  nfs:
    server: nas           # Tailscale MagicDNS hostname
    path: /volume1/media
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: media-nfs-pv
  resources:
    requests:
      storage: 1Ti
```

Key details:
- `storageClassName: ""` ensures static binding (not dynamic provisioning)
- `volumeName` in the PVC binds it to the specific PV
- `Retain` reclaim policy prevents accidental data loss
- Use the NAS's Tailscale hostname, not an IP address

## What You Now Have

- A Kubernetes cluster running on your server
- Remote access via Tailscale
- Storage for persistent workloads

## Next Steps

- [[argocd-config|Configure ArgoCD]] - GitOps deployments
- Install ingress - the Tailscale operator for tailnet-only services (BlumeOps), or an ingress controller plus cert-manager for public HTTPS

## BlumeOps Specifics

BlumeOps' cluster configuration includes:
- Tailscale operator for automatic ingress
- NFS mounts from [[sifaka]] for media storage
- CloudNativePG for PostgreSQL databases

See [[cluster|Cluster Reference]] and [[apps|Apps Reference]] for full details.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't connect remotely | Check the API server binds all interfaces and 6443 isn't firewalled on the Tailscale IP |
| Pods stuck pending | Check storage class is available |
| Certificate errors | Re-fetch the kubeconfig; the embedded CA and client cert must match the server's |
