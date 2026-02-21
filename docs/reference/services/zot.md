---
title: Zot
modified: 2026-02-07
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

When [[cluster|minikube]] pulls an image, containerd checks zot first. If cached, returns immediately. If not, zot fetches from upstream, caches it, then returns.

## Security Model

OIDC authentication via [[authentik]], with API key support for CI. Three-tier access control:

| Role | Permissions | Use case |
|------|------------|----------|
| Anonymous | read | Pull images without auth |
| `artifact-workloads` group | read, create | CI push (new tags only, no overwrite/delete) |
| `admins` group | read, create, update, delete | Break-glass admin access |

CI authenticates with a zot API key generated from the `zot-ci` service account's OIDC session. The key is stored in the `Forgejo Secrets` 1Password item (field `zot-ci-api`) and synced to Forgejo Actions secrets via ansible.

## API Key Rotation

The `zot-ci` API key expires every **90 days**. To rotate:

1. In Authentik admin UI, impersonate the `zot-ci` user
2. Visit `https://registry.ops.eblu.me` — you'll land on the login page
3. Click "SIGN IN WITH OIDC" to authenticate as zot-ci
4. Navigate to `https://registry.ops.eblu.me/user/apikey`
5. Generate a new API key, copy it to clipboard
6. Update 1Password:
   ```fish
   pbpaste | op item edit "Forgejo Secrets" --vault blumeops "zot-ci-api[password]=-"
   ```
7. Sync to Forgejo: `mise run provision-indri -- --tags forgejo_actions_secrets`

## Related

- [[forgejo]] - Container build CI
- [[cluster|Cluster]] - Registry consumer
- [[authentik]] - OIDC identity provider
