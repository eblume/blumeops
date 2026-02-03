---
title: Zot
tags:
  - service
  - registry
---

# Zot

OCI-native container registry providing pull-through cache and private image storage.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://registry.ops.eblu.me |
| **Local Port** | 5050 |
| **Data** | `~/zot` |
| **Config** | `~/.config/zot/config.json` |
| **LaunchAgent** | mcquack |

## Namespace Convention

| Path | Source |
|------|--------|
| `registry.ops.eblu.me/docker.io/*` | Cached from Docker Hub |
| `registry.ops.eblu.me/ghcr.io/*` | Cached from GHCR |
| `registry.ops.eblu.me/quay.io/*` | Cached from Quay |
| `registry.ops.eblu.me/blumeops/*` | Private images |

## Pull-Through Cache

When [[reference/kubernetes/cluster|minikube]] pulls an image, containerd checks zot first. If cached, returns immediately. If not, zot fetches from upstream, caches it, then returns.

## Security Model

Network access only (no authentication). Defense is the Tailscale ACL boundary.

## Related

- [[reference/services/forgejo|Forgejo]] - Container build CI
- [[reference/kubernetes/cluster|Cluster]] - Registry consumer
