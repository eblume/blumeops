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
| **ArgoCD Apps** | `tailscale-operator` (indri/minikube), `tailscale-operator-ringtail` (ringtail/k3s) |

The operator runs on **both** clusters — indri's minikube and ringtail's k3s.
Both apps layer on the shared `tailscale-operator-base` kustomize directory
(operator manifest, `ProxyClass`, `dnsconfig`); each cluster supplies its own
`ProxyGroup` (indri: 2 replicas, ringtail: 1) and OAuth `ExternalSecret`. See
[[ringtail]] and [[migrate-wave1-ringtail]] for the ongoing migration of k8s
workloads onto ringtail.

## Local Images

Both the operator and the proxy run locally-built images from the forge
mirror (`mirrors/tailscale`), not Docker Hub:

| Image | Build | Used by |
|-------|-------|---------|
| `blumeops/tailscale-operator` | `containers/tailscale-operator/` (`container.py` for indri/arm64, `default.nix` `-nix` tag for ringtail/amd64) | operator Deployment, via each overlay's `images:` override |
| `blumeops/tailscale` | `containers/tailscale/` (same dual build) | `ProxyClass` proxy pods, via a strategic-merge patch in each overlay |

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
   AND the affected state Secret, then restart the pod (see
   [[rebuild-minikube-cluster]]).

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
