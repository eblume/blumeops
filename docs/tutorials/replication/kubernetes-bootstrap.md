---
title: Kubernetes Bootstrap
modified: 2026-03-25
last-reviewed: 2026-03-25
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
| **Minikube** | Single-node, macOS | Yes |
| **k3s** | Single-node, Linux | Yes (ringtail) |
| **kind** | Local development | - |
| **kubeadm** | Multi-node clusters | - |

This tutorial uses minikube, but principles apply broadly.

For BlumeOps specifics, see [[cluster|Cluster Reference]].

## Step 1: Install Minikube

### macOS

```bash
brew install minikube
```

### Linux

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

## Step 2: Create the Cluster

```bash
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8g \
  --disk-size=100g \
  --apiserver-names=k8s.your-tailnet.ts.net,$(hostname) \
  --listen-address=0.0.0.0
```

Key flags:
- `--apiserver-names` - Include your Tailscale hostname for remote access
- `--listen-address=0.0.0.0` - Allow connections from other machines

## Step 3: Verify the Cluster

```bash
kubectl get nodes
# Should show your node as Ready

kubectl get pods -A
# Should show system pods running
```

## Step 4: Expose via Tailscale

To access the cluster from other Tailscale devices, expose the API server:

### Option A: Tailscale Serve (Simple)

```bash
tailscale serve --bg --tcp 6443 tcp://$(minikube ip):8443
```

### Option B: Tailscale Kubernetes Operator (Advanced)

For production-like setup, install the Tailscale operator which manages ingress automatically.

BlumeOps uses TCP passthrough via Caddy - see [[routing|Routing Reference]].

## Step 5: Configure Remote Access

On your workstation, add a context for the remote cluster:

```bash
# Copy the CA cert from the server
scp server:~/.minikube/ca.crt ~/.kube/minikube-ca.crt

# Add the cluster
kubectl config set-cluster minikube-remote \
  --server=https://k8s.your-tailnet.ts.net:6443 \
  --certificate-authority=$HOME/.kube/minikube-ca.crt

# Add credentials (copy from server's ~/.kube/config)
kubectl config set-credentials minikube-remote \
  --client-certificate=... \
  --client-key=...

# Add context
kubectl config set-context minikube-remote \
  --cluster=minikube-remote \
  --user=minikube-remote

# Test
kubectl --context=minikube-remote get nodes
```

## Step 6: Storage Configuration

For persistent workloads, configure storage:

### Local Path Provisioner (Simple)

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
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
- Install essential addons (ingress controller, cert-manager)

## BlumeOps Specifics

BlumeOps' cluster configuration includes:
- Tailscale operator for automatic ingress
- NFS mounts from [[sifaka]] for media storage
- CloudNativePG for PostgreSQL databases

See [[cluster|Cluster Reference]] and [[apps|Apps Reference]] for full details.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't connect remotely | Check `--apiserver-names` includes Tailscale hostname |
| Pods stuck pending | Check storage class is available |
| Connection refused | Verify `--listen-address=0.0.0.0` was set |
| Certificate errors | Ensure CA cert matches server's |
