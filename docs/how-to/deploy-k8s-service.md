---
title: Deploy K8s Service
modified: 2026-02-15
last-reviewed: 2026-02-15
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
    repoURL: ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git
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

Add a [[tailscale-operator|Tailscale Ingress]] routed through the ProxyGroup with Homepage annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <service>-tailscale
  namespace: <service>
  annotations:
    tailscale.com/proxy-class: "default"
    tailscale.com/proxy-group: "ingress"
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "Service Name"
    gethomepage.dev/group: "Services"
    gethomepage.dev/icon: "<service>.png"
    gethomepage.dev/href: "https://<service>.ops.eblu.me"
    gethomepage.dev/pod-selector: "app=<service>"
spec:
  ingressClassName: tailscale
  defaultBackend:
    service:
      name: <service>
      port:
        number: 80
  tls:
    - hosts:
        - <service>
```

Key points:
- **`proxy-group: "ingress"`** routes through the shared ProxyGroup instead of spawning a per-ingress proxy
- **Do not use `rules:` with `host:`** — the ProxyGroup proxy receives the FQDN as Host header (e.g. `<service>.tail8d86e.ts.net`), so a short `host: <service>` won't match. Use `defaultBackend` instead.
- **`tls.hosts`** sets the MagicDNS hostname (becomes `<service>.tail8d86e.ts.net`)
- **`gethomepage.dev/group`** — use one of the existing groups: "Services", "Content", or "Infrastructure"
- **`tailscale.com/tags`** is not needed in the default case — the ProxyGroup already applies `tag:k8s`. Only add this annotation when the service needs public internet access via the [[flyio-proxy]]. When you do, you must include both tags (setting tags overrides the ProxyGroup default):
  ```yaml
  tailscale.com/tags: "tag:k8s,tag:flyio-target"
  ```
  Then add a Caddy route and Fly.io proxy config per [[expose-service-publicly]].

## Add Caddy Route (if needed)

If other pods need to access the service, add to `ansible/roles/caddy/defaults/main.yml`:

```yaml
caddy_services:
  - name: <service>
    host: "<service>.{{ caddy_domain }}"
    backend: "https://<service>.tail8d86e.ts.net"
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
- [ ] Tailscale Ingress via ProxyGroup with Homepage annotations
- [ ] Caddy route (if pod-to-service access needed)
- [ ] Tested on feature branch
- [ ] PR reviewed and merged
- [ ] Reset to main branch

## Related

- [[adding-a-service]] - Full tutorial with explanations
- [[apps]] - ArgoCD application registry
- [[routing]] - Service routing options
