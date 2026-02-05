---
title: tailscale-operator
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

When you create an Ingress with `ingressClassName: tailscale`:

1. Operator provisions a Tailscale node for the service
2. Service becomes accessible at `<hostname>.tail8d86e.ts.net`
3. TLS is handled automatically via Tailscale

## Limitations

Services exposed via Tailscale Ingress are **not accessible** from:
- Other Kubernetes pods (they're not Tailscale clients)
- Docker containers on indri

For pod-to-service communication, use [[routing|Caddy]] (`*.ops.eblu.me`) instead.

## Related

- [[tailscale]] - Network configuration
- [[routing]] - Service routing options
- [[apps]] - Application registry
