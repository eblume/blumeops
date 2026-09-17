---
title: Deploy K8s Service
modified: 2026-09-17
last-reviewed: 2026-09-13
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
├── kustomization.yaml
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
    repoURL: ssh://forgejo@forge.eblu.me:2222/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/<service>
  destination:
    server: https://kubernetes.default.svc
    namespace: <service>
  syncPolicy:
    automated: {}
    syncOptions:
    - CreateNamespace=true
    managedNamespaceMetadata:
      labels:
        pod-security.kubernetes.io/warn: restricted
        pod-security.kubernetes.io/audit: restricted
```

- **`repoURL` names `forge.eblu.me`, not `forge.ops.eblu.me`.** The Forgejo
  webhook that triggers syncs matches the payload's `html_url` (the public
  `forge.eblu.me` host) against each app's `repoURL`; the CoreDNS rewrite in
  `nixos/ringtail/configuration.nix` makes the name fetch over the tailnet.
  See the "Why the Applications say `forge.eblu.me`" section of [[argocd]].
- **`automated: {}`, nothing else spelled out.** `automated` is the default
  posture for a workload application — without it the new service becomes a
  fifth manual-sync app with no reason stated for being one. Never write
  `prune: false` / `selfHeal: false` explicitly: the controller round-trips
  the spec through `omitempty` structs, so explicit falses vanish from the
  live CR and the `apps` root app flaps `OutOfSync`. `selfHeal` is off
  fleet-wide; add `prune: true` only when the kustomization uses a
  `configMapGenerator` (superseded hash-suffixed ConfigMaps would otherwise
  accumulate and the app would read `OutOfSync` forever). See
  [[argocd#Sync Policy]] for what each setting buys.
- **The PSA labels** put the new namespace under Pod Security Admission at
  `restricted`; use `baseline` instead if the workload needs hostPath
  (ollama and talos do). Exemptions and deferrals are documented in
  [[security]].

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
- **`defaultBackend` port** must match the port of the Service in `service.yaml`
- **`proxy-group: "ingress"`** routes through the shared ProxyGroup instead of spawning a per-ingress proxy
- **Do not use `rules:` with `host:`** — the ProxyGroup proxy receives the FQDN as Host header (e.g. `<service>.tail8d86e.ts.net`), so a short `host: <service>` won't match. Use `defaultBackend` instead.
- **`tls.hosts`** sets the MagicDNS hostname (becomes `<service>.tail8d86e.ts.net`)
- **`gethomepage.dev/group`** — use one of the existing groups: "Host Services", "Home", "Content", "Infrastructure", or "Services" (the layouts in `argocd/manifests/homepage/settings.yaml`)
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
kubectl --context=k3s-ringtail -n <service> get pods
kubectl --context=k3s-ringtail -n <service> logs -f deployment/<service>

# After PR merge, undo the branch pin from above.
# This is the ONLY post-merge step: the pin persists until you clear it, but
# the merge itself already deployed (see [[argocd#Sync Policy]]). Do not add a
# sync here — you would be racing the auto-sync your merge started.
argocd app set <service> --revision main
```

The first step is the one agents cannot run (read-only `argocd` in the pod):
they file `argocd-sync-apps.yaml` via [[request-a-privileged-run]] instead,
which pins the root to the bound SHA, syncs, and resets it to `main` — a
plain SHA sync would pin the root and mask later `argocd/apps/` drift.

## Checklist

- [ ] Manifests in `argocd/manifests/<service>/`
- [ ] Application in `argocd/apps/<service>.yaml`
- [ ] PSA namespace labels on the Application (restricted, or baseline if hostPath is needed)
- [ ] Tailscale Ingress via ProxyGroup with Homepage annotations
- [ ] Caddy route (if pod-to-service access needed)
- [ ] Tested on feature branch
- [ ] PR reviewed and merged (this is the deploy)
- [ ] Branch pin cleared, if one was set
- [ ] Service added to `service-versions.yaml` for version tracking

## Related

- [[adding-a-service]] - Full tutorial with explanations
- [[apps]] - ArgoCD application registry
- [[routing]] - Service routing options
