---
title: Adding a Service
modified: 2026-04-08
last-reviewed: 2026-04-08
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
- `kubectl` configured with the `k3s-ringtail` context
- `argocd` CLI installed (via Brewfile: `brew bundle`)

## Overview

Adding a service involves:
1. Creating Kubernetes manifests
2. Creating an ArgoCD Application
3. Configuring Tailscale ingress
4. Adding Homepage dashboard entry
5. Creating a reference card
6. Setting up Grafana dashboards (optional)

## Step 1: Create Manifests Directory

Create a directory for your service's Kubernetes manifests:

```
argocd/manifests/<service-name>/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
├── ingress-tailscale.yaml
└── configmap.yaml  # if needed
```

### Kustomization

Every service needs a `kustomization.yaml` that lists its resources and pins the container image tag. ArgoCD uses kustomize to render manifests.

```yaml
# argocd/manifests/myservice/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - ingress-tailscale.yaml

images:
  - name: registry.ops.eblu.me/myservice
    newTag: v1.0.0
```

Use the `:kustomized` sentinel tag in `deployment.yaml` — kustomize replaces it with the `newTag` from above. To deploy a new version, update `newTag` here (not in the deployment).

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
        image: registry.ops.eblu.me/myservice:kustomized
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
  tls:
  - hosts:
    - myservice
  rules:
  - http:
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
    repoURL: ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/myservice
  destination:
    server: https://kubernetes.default.svc
    namespace: myservice
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
```

## Step 5: Create a Reference Card

Add a reference card at `docs/reference/services/<service-name>.md` so the service is discoverable in documentation. Keep it short — target a 30-second reading time or less. Include a Quick Reference table with URLs, namespace, and image, then link out to how-to cards or other docs for anything deeper.

```yaml
---
title: My Service
modified: 2026-04-08
tags:
  - service
---
```

```markdown
# My Service

One-sentence description of what the service does.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://myservice.ops.eblu.me |
| **Tailscale URL** | https://myservice.tail8d86e.ts.net |
| **Namespace** | `myservice` |
| **Image** | `registry.ops.eblu.me/myservice` |
| **Manifests** | `argocd/manifests/myservice/` |

## Related

- [[adding-a-service]] - Deployment tutorial
```

See existing cards like [[navidrome]] or [[kiwix]] for examples.

## Step 6: Add Caddy Route (Optional)

If the service needs to be accessible from other pods or containers, add a Caddy route in `ansible/roles/caddy/defaults/main.yml`:

```yaml
caddy_services:
  # ... existing services ...
  - name: myservice
    upstream: "https://myservice.tail8d86e.ts.net"
```

Then run `mise run provision-indri -- --tags caddy` to apply.

This enables access via `https://myservice.ops.eblu.me`. See [[routing]] for details on when this is needed.

## Step 7: Deploy

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
kubectl --context=k3s-ringtail -n myservice get pods
kubectl --context=k3s-ringtail -n myservice logs -f deployment/myservice
```

### After PR Merge

Reset to main branch:
```bash
argocd app set myservice --revision main
argocd app sync myservice
```

## Step 8: Add Observability (Optional)

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
- [ ] Reference card created in `docs/reference/services/`
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
