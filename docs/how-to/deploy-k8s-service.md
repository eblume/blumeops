---
title: Deploy K8s Service
modified: 2026-02-07
tags:
  - how-to
  - kubernetes
  - argocd
---

# Deploy a Kubernetes Service

Quick reference for deploying a new service to BlumeOps Kubernetes via ArgoCD. See [[adding-a-service|the tutorial]] for detailed explanations.

## Create Manifests

```
argocd/manifests/<service>/
├── deployment.yaml
├── service.yaml
└── ingress-tailscale.yaml
```

Namespace should match service name. Use `registry.ops.eblu.me` for images.

## Create ArgoCD Application

```yaml
# argocd/apps/<service>.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <service>
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/<service>
  destination:
    server: https://kubernetes.default.svc
    namespace: <service>
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
```

## Configure Ingress

Add [[tailscale-operator|Tailscale Ingress]] with Homepage annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <service>
  namespace: <service>
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "Service Name"
    gethomepage.dev/group: "Apps"
    gethomepage.dev/icon: "<service>.png"
    gethomepage.dev/href: "https://<service>.ops.eblu.me"
    gethomepage.dev/pod-selector: "app=<service>"
spec:
  ingressClassName: tailscale
  rules:
  - host: <service>
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: <service>
            port:
              number: 80
```

## Add Caddy Route (if needed)

If other pods need to access the service, add to `ansible/roles/caddy/defaults/main.yml`:

```yaml
caddy_services:
  - name: <service>
    upstream: "https://<service>.tail8d86e.ts.net"
```

Then: `mise run provision-indri -- --tags caddy`

See [[routing]] for when Caddy is needed.

## Deploy

```bash
# Sync apps to pick up new Application
argocd app sync apps

# Test on feature branch first
argocd app set <service> --revision <branch>
argocd app sync <service>

# Verify
kubectl --context=minikube-indri -n <service> get pods
kubectl --context=minikube-indri -n <service> logs -f deployment/<service>

# After PR merge, reset to main
argocd app set <service> --revision main
argocd app sync <service>
```

## Checklist

- [ ] Manifests in `argocd/manifests/<service>/`
- [ ] Application in `argocd/apps/<service>.yaml`
- [ ] Tailscale Ingress with Homepage annotations
- [ ] Caddy route (if pod-to-service access needed)
- [ ] Tested on feature branch
- [ ] PR reviewed and merged
- [ ] Reset to main branch

## Related

- [[adding-a-service]] - Full tutorial with explanations
- [[apps]] - ArgoCD application registry
- [[routing]] - Service routing options
