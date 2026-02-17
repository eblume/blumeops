---
title: Adding a Service
modified: 2026-02-07
tags:
  - tutorials
  - argocd
  - kubernetes
---

# Adding an ArgoCD-Managed Service

> **Audiences:** Contributor, Replicator

This tutorial walks through deploying a new service to BlumeOps via ArgoCD, including ingress configuration, homepage integration, and observability setup.

## Prerequisites

- Access to the [[tailscale|Tailscale]] network
- `kubectl` configured with `minikube-indri` context
- `argocd` CLI installed (via Brewfile: `brew bundle`)

## Overview

Adding a service involves:
1. Creating Kubernetes manifests
2. Creating an ArgoCD Application
3. Configuring Tailscale ingress
4. Adding Homepage dashboard entry
5. Setting up Grafana dashboards (optional)

## Step 1: Create Manifests Directory

Create a directory for your service's Kubernetes manifests:

```
argocd/manifests/<service-name>/
├── deployment.yaml
├── service.yaml
├── ingress-tailscale.yaml
└── configmap.yaml  # if needed
```

### Example Deployment

```yaml
# argocd/manifests/myservice/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
  namespace: myservice
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myservice
  template:
    metadata:
      labels:
        app: myservice
    spec:
      containers:
      - name: myservice
        image: registry.ops.eblu.me/myservice:v1.0.0
        ports:
        - containerPort: 8080
```

### Example Service

```yaml
# argocd/manifests/myservice/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
  namespace: myservice
spec:
  selector:
    app: myservice
  ports:
  - port: 80
    targetPort: 8080
```

## Step 2: Configure Tailscale Ingress

Create an Ingress to expose the service via Tailscale. See [[tailscale-operator]] for details.

```yaml
# argocd/manifests/myservice/ingress-tailscale.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myservice
  namespace: myservice
spec:
  ingressClassName: tailscale
  rules:
  - host: myservice
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myservice
            port:
              number: 80
```

This exposes the service at `https://myservice.tail8d86e.ts.net`.

## Step 3: Add Homepage Annotations

Add annotations to the Ingress for automatic Homepage dashboard discovery:

```yaml
metadata:
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "My Service"
    gethomepage.dev/group: "Apps"
    gethomepage.dev/icon: "myservice.png"
    gethomepage.dev/description: "Short description"
    gethomepage.dev/href: "https://myservice.ops.eblu.me"
    gethomepage.dev/pod-selector: "app=myservice"
```

Icons use [Dashboard Icons](https://github.com/walkxcode/dashboard-icons) format.

## Step 4: Create ArgoCD Application

Create an Application manifest to tell ArgoCD about your service:

```yaml
# argocd/apps/myservice.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myservice
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/myservice
  destination:
    server: https://kubernetes.default.svc
    namespace: myservice
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
```

## Step 5: Add Caddy Route (Optional)

If the service needs to be accessible from other pods or containers, add a Caddy route in `ansible/roles/caddy/defaults/main.yml`:

```yaml
caddy_services:
  # ... existing services ...
  - name: myservice
    upstream: "https://myservice.tail8d86e.ts.net"
```

Then run `mise run provision-indri -- --tags caddy` to apply.

This enables access via `https://myservice.ops.eblu.me`. See [[routing]] for details on when this is needed.

## Step 6: Deploy

### Testing on a Feature Branch

For new services, point ArgoCD at your feature branch first:

```bash
# Sync the apps application to pick up your new Application
argocd app sync apps

# Point your app at the feature branch
argocd app set myservice --revision feature/your-branch
argocd app sync myservice
```

### Verify Deployment

```bash
kubectl --context=minikube-indri -n myservice get pods
kubectl --context=minikube-indri -n myservice logs -f deployment/myservice
```

### After PR Merge

Reset to main branch:
```bash
argocd app set myservice --revision main
argocd app sync myservice
```

## Step 7: Add Observability (Optional)

### Prometheus Metrics

If your service exposes Prometheus metrics, add scrape annotations:

```yaml
# In deployment.yaml pod template
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Grafana Dashboard

Create a ConfigMap in `argocd/manifests/grafana-config/dashboards/`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myservice-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: "Services"
data:
  myservice.json: |
    { ... dashboard JSON ... }
```

See [[grafana]] for dashboard provisioning details.

## Checklist

- [ ] Manifests created in `argocd/manifests/<service>/`
- [ ] ArgoCD Application created in `argocd/apps/`
- [ ] Tailscale Ingress configured
- [ ] Homepage annotations added
- [ ] Caddy route added (if needed for pod access)
- [ ] Feature branch tested via ArgoCD
- [ ] Metrics/dashboard configured (if applicable)
- [ ] PR created and reviewed
- [ ] Reset to main after merge
- [ ] Service added to `service-versions.yaml` for version tracking

## Related

- [[argocd]] - GitOps platform
- [[tailscale-operator]] - Kubernetes ingress
- [[routing]] - Service routing options
- [[grafana]] - Dashboard configuration
- [[apps]] - Application registry
