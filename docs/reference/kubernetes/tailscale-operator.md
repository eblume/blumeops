---
title: Tailscale Operator
modified: 2026-06-08
last-reviewed: 2026-06-08
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
`ProxyGroup` (indri: 2 replicas, ringtail: 1) and OAuth `ExternalSecret`. The
ringtail overlay additionally rewrites the proxy image to a locally nix-built
mirror. See [[ringtail]] and [[migrate-wave1-ringtail]] for the ongoing
migration of k8s workloads onto ringtail.

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
