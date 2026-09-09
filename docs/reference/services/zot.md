---
title: Zot
modified: 2026-09-09
last-reviewed: 2026-09-09
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

When the [[cluster|k3s cluster]] pulls an image, containerd checks zot first. If cached, returns immediately. If not, zot fetches from upstream, caches it, then returns.

## Security Model

OIDC authentication via [[authentik]], with API key support for CI.

| Role | Permissions | Use case |
|------|------------|----------|
| Anonymous | read | Pull images without auth |
| `artifact-workloads` group | read, create | CI push (new tags only, no overwrite/delete) |
| `admins` group | read, create, update, delete | Break-glass admin access |
| `zot-talos`, `zot-horkos` | create, update on their own image path only | per-repo release-CI push key (horkos#17 step 3) |

CI authenticates with a zot API key generated from the `zot-ci` service account's OIDC session. The key is stored in the `Forgejo Secrets` 1Password item (field `zot-ci-api`) and synced to Forgejo Actions secrets via ansible.

The per-repo identities exist because a repo's Forgejo Actions secrets are readable by anyone who can push to that repo, so each release CI's key is scoped by zot accessControl to create+update on its own image path only. zot's accessControl uses longest-match, so the per-path `blumeops/talos` and `blumeops/horkos` entries restate the base `**` policies verbatim rather than inheriting them.

## API Key Rotation

The `zot-ci` API key expires every **90 days**. `zot-talos` and `zot-horkos` rotate the same way (impersonate each user, /user/apikey); their keys live in the `Forgejo Secrets` item as `zot-talos-api` / `zot-horkos-api`. To rotate:

1. In Authentik admin UI, impersonate the `zot-ci` user
2. Visit `https://registry.ops.eblu.me` — you'll land on the login page
3. Click "SIGN IN WITH OIDC" to authenticate as zot-ci
4. Navigate to `https://registry.ops.eblu.me/user/apikey`
5. Generate a new API key, copy it to clipboard
6. Update 1Password:
   ```fish
   set -l NEWKEY (pbpaste); op item edit "Forgejo Secrets" --vault blumeops "zot-ci-api[password]=$NEWKEY"; set -e NEWKEY
   ```
   The value is briefly visible to other `ps`-readers on this machine (single-user mac, acceptable tradeoff). The older `pbpaste | op item edit ... "field[password]=-"` stdin syntax was rejected by op 2.34 as "invalid JSON" — recent op versions treat piped input as a full JSON template.
7. Sync to Forgejo: `mise run provision-indri -- --tags forgejo_actions_secrets`

## Related

- [[forgejo]] - Container build CI
- [[cluster|Cluster]] - Registry consumer
- [[authentik]] - OIDC identity provider
- [[harden-zot-registry]] - Security hardening guide
- [[service-versions]] - Version tracking for deployed services
