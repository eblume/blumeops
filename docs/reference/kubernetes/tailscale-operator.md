---
title: Tailscale Operator
modified: 2026-06-09
last-reviewed: 2026-06-09
tags:
  - kubernetes
  - tailscale
---

# Tailscale Kubernetes Operator

The Tailscale operator enables Kubernetes services to be exposed directly on the Tailscale network via Ingress resources.

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `tailscale` |
| **Upstream** | `mirrors/tailscale` on forge (static manifest, pinned `v1.94.2`) |
| **ArgoCD Apps** | `tailscale-operator-ringtail` (ringtail/k3s) |

The app layers on the `tailscale-operator-base` kustomize directory
(operator manifest, `ProxyClass`, `dnsconfig`) and supplies the
`ProxyGroup` (1 replica) and OAuth `ExternalSecret`. (A second operator
ran on indri's minikube until the cluster retired —
[[retire-minikube]].)

## Local Images

Both the operator and the proxy run locally-built images from the forge
mirror (`mirrors/tailscale`), not Docker Hub:

| Image | Build | Used by |
|-------|-------|---------|
| `blumeops/tailscale-operator` | `containers/tailscale-operator/` (`default.nix` `-nix` tag, amd64) | operator Deployment, via the overlay's `images:` override |
| `blumeops/tailscale` | `containers/tailscale/` (same build) | `ProxyClass` proxy pods, via a strategic-merge patch in the overlay |

The ProxyClass image must be set with a **patch**, not kustomize's `images:`
directive — that directive only rewrites standard container fields, not
custom-resource fields like `ProxyClass.spec.statefulSet.pod.tailscaleContainer.image`.

The `dnsconfig` nameserver image (`tailscale/k8s-nameserver:stable`) is still
upstream — a known follow-up.

## Rollout Safety (device identity)

Proxy and operator tailnet identity lives in Kubernetes state Secrets in the
`tailscale` namespace, not in pods or images. An image swap rolls the
Deployment/StatefulSets but pods re-authenticate with their existing node
keys — devices keep their names. Shadow devices (`foo-1` suffixes) appear only
when a pod registers *fresh* while a stale device record still holds the name
(deleted state Secrets, cluster rebuilds). When rolling out image changes:

1. Never delete the `tailscale` namespace state Secrets.
2. Verify after sync: pods healthy, device names unchanged in the admin
   console, `mise run services-check` green.
3. If a collision does occur: delete the stale device in the admin console
   AND the affected state Secret, then restart the pod.

## How It Works

Ingresses use a shared ProxyGroup (`ingress`) rather than per-service Tailscale nodes. When you create an Ingress with `ingressClassName: tailscale`:

1. Operator configures the shared ProxyGroup pods to serve the new Ingress
2. Service gets a VIP (Virtual IP) address on the tailnet
3. Service becomes accessible at `<hostname>.tail8d86e.ts.net`
4. TLS is handled automatically via Tailscale

Two requirements for VIP routing to work:

1. Tailnet clients must have `--accept-routes` enabled to route to VIP addresses.
2. Ingress rules must **not** set an explicit `host:` field. The ProxyGroup
   proxy receives the FQDN as the `Host` header (e.g.
   `prometheus.tail8d86e.ts.net`), which won't match a short name. Use
   `host: "*"` or omit `host:` entirely.

Services can be individually tagged (e.g., `tag:flyio-target`) via Ingress annotations to control which ACL grants apply. See [[expose-service-publicly]] for the tagging workflow.

## Limitations

Services exposed via Tailscale Ingress are **not accessible** from:
- Other Kubernetes pods (they're not Tailscale clients)
- Docker containers on indri

For pod-to-service communication, use [[routing|Caddy]] (`*.ops.eblu.me`) instead.

## Related

- [[tailscale]] - Network configuration
- [[routing]] - Service routing options
- [[apps]] - Application registry
