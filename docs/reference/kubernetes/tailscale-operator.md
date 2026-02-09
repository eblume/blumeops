---
title: Tailscale Operator
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
| **Helm Chart** | `tailscale/tailscale-operator` |
| **ArgoCD App** | `tailscale-operator` |

## How It Works

Ingresses use a shared ProxyGroup (`ingress`) rather than per-service Tailscale nodes. When you create an Ingress with `ingressClassName: tailscale`:

1. Operator configures the shared ProxyGroup pods to serve the new Ingress
2. Service gets a VIP (Virtual IP) address on the tailnet
3. Service becomes accessible at `<hostname>.tail8d86e.ts.net`
4. TLS is handled automatically via Tailscale

Tailnet clients must have `--accept-routes` enabled to route to VIP addresses.

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
