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

Every CI key expires after **90 days**. Rotation is a command, not a browser
session:

```fish
mise run zot-apikey-rotate zot-ci        # or zot-talos, zot-horkos
mise run zot-apikey-rotate zot-ci --dry-run   # just prove the current key still works
```

zot's key-management endpoints accept an API key as basic-auth credentials,
so a live key mints its own successor. The task reads the current key from the
`Forgejo Secrets` item (blumeops vault; fields `zot-ci-api`, `zot-talos-api`,
`zot-horkos-api`), mints a new one, proves the new key authenticates, writes
the master copy back, writes the consumer copy — `blumeops-ci/zot-ci`
(`api-key`) for `zot-ci`, the `ZOT_PUSH_API_KEY` Actions secret on
`eblume/talos` / `eblume/horkos` for the per-repo identities — and then
revokes every other key the identity holds (`--keep-others` to skip). Any
failure before the writes leaves the old key valid and its consumer untouched.
Key material never touches argv or the terminal.

Rotate before expiry, not after: an expired key cannot mint, and the chain
has to be re-seeded in the browser.

### Bootstrap (first key, or a broken chain)

Needed once per new identity, or when a key expired before anyone rotated it.
This is the one step that stays in the browser: Authentik's OIDC authorize
view requires a login event on the session, and a session created through
API-token impersonation (`POST /api/v3/core/users/<pk>/impersonate/`) has
none, so it bounces to the login flow. Browser impersonation works because it
rides on your own logged-in session.


1. In the Authentik admin UI, impersonate the identity (`zot-ci`, `zot-talos`
   or `zot-horkos`)
2. Visit `https://registry.ops.eblu.me` and click "SIGN IN WITH OIDC"
3. Navigate to `https://registry.ops.eblu.me/user/apikey`, generate a key
   (any expiry — it is about to be retired), copy it
4. Stop impersonating, then hand the key to the task from the clipboard:
   ```fish
   pbpaste | mise run zot-apikey-rotate zot-talos --key-stdin
   ```
   That verifies the pasted key, mints the real one, stores it, syncs the
   consumer and revokes the pasted bootstrap key in one step.

## Related

- [[forgejo]] - Container build CI
- [[cluster|Cluster]] - Registry consumer
- [[authentik]] - OIDC identity provider
- [[harden-zot-registry]] - Security hardening guide
- [[service-versions]] - Version tracking for deployed services
