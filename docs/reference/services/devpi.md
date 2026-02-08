---
title: Devpi
tags:
  - service
  - python
---

# devpi (PyPI Proxy)

PyPI caching proxy and private package index.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://pypi.ops.eblu.me |
| **Namespace** | `devpi` |
| **ArgoCD App** | `devpi` |
| **Storage** | 50Gi PVC |
| **Image** | `registry.ops.eblu.me/blumeops/devpi:latest` |

## Indices

| Index | Purpose |
|-------|---------|
| `root/pypi` | PyPI mirror/cache (auto-created) |
| `eblume/dev` | Private packages (inherits from root/pypi) |

## Credentials

Root password stored in 1Password (blumeops vault), injected via ExternalSecret.

## Related

- [[use-pypi-proxy]] - Client configuration and package uploads
- [[argocd]] - Deployment
- [[1password]] - Secrets management
