---
title: Zot
modified: 2026-09-16
last-reviewed: 2026-09-16
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
| `artifact-workloads` group | read, create | CI push (new tags only, no overwrite/delete); grandfathered until the cleanup PR retires it |
| `ci-artifacts` group (`ci-zot`) | read, create | CI push for `build-container` (new tags only, no overwrite/delete); ci tier of eblume/blumeops#1039 step 2b, additive until the cleanup PR retires `zot-ci` |
| `admins` group | read, create, update, delete | Break-glass admin access |
| `ci-zot-talos`, `ci-zot-horkos` | create, update on their own image path only | per-repo release-CI push keys (horkos#17 step 3; ci tier of eblume/blumeops#1039) |
| `horkos-zot` | create, update on `blumeops/cv` only | the horkos publisher's push identity for cv tarballs (horkos#17 step 4; horkos tier of eblume/blumeops#1039 step 2b), consumed by the horkos deployment via ESO, not by any repo CI |

CI authenticates with a zot API key generated from the `zot-ci` service account's OIDC session. The key is stored in the `Forgejo Secrets` 1Password item (field `zot-ci-api`) and mirrored to `blumeops-ci/zot-ci` (`api-key`); workflows `op read` it at job time with `BLUMEOPS_CI_OP_TOKEN` — it is not a Forgejo Actions secret. The ci-tier successor `ci-zot` (group `ci-artifacts`) is additive: its key lives in the same places — `Forgejo Secrets` field `ci-zot-api` and the `blumeops-ci/ci-zot` item — and `build-container.yaml` moves to reading it when the flip PR merges.

The per-repo `ZOT_PUSH_API_KEY` Actions secrets are declared in the `forgejo_actions_secrets` ansible role and provisioned from the same master fields, so after a `mise run zot-apikey-rotate` of a per-repo identity, the next `mise run provision-indri -- --tags forgejo_actions_secrets` re-syncs the secret the rotation already wrote (a no-op, not a second key).

The per-repo identities exist because a repo's Forgejo Actions secrets are readable by anyone who can push to that repo, so each release CI's key is scoped by zot accessControl to create+update on its own image path only. zot's accessControl uses longest-match, so the per-path `blumeops/talos`, `blumeops/horkos` and `blumeops/cv` entries restate the base `**` policies verbatim rather than inheriting them.

## API Key Rotation

Every CI key expires after **90 days**. Rotation is a command, not a browser
session:

```fish
mise run zot-apikey-rotate zot-ci        # or ci-zot, ci-zot-talos, ci-zot-horkos, horkos-zot
mise run zot-apikey-rotate zot-ci --dry-run   # just prove the current key still works
```

zot's key-management endpoints accept an API key as basic-auth credentials,
so a live key mints its own successor.

**CI-tier cutover (complete, 2026-09-14).** The per-repo release-CI push
identities moved through the tier-first scheme of eblume/blumeops#1039 to
the ci tier (authorized by merging to main): `ci-zot-talos` and
`ci-zot-horkos`, each verified by a release push under the new identity
(talos#224, horkos#32). The intermediate tier-first identities
(`talos-zot` / `horkos-zot`) are retired by this change: their blueprint
entries, the `talos-artifacts` group entry and its zot-app policy binding,
the accessControl grants, and the `zot-apikey-rotate` entries are gone from
the repo here. The live Authentik users and group and the `talos-zot-api` /
`horkos-zot-api` master fields are deleted by the ceremony after sync —
the worker stops managing them, but the deletes themselves are UI acts. The
`horkos-artifacts` group stays — it is the seat of the horkos publisher
identity `horkos-zot`, added by this PR: the blueprint user, the
`blumeops/cv` accessControl grant, the `zot-apikey-rotate` entry, and the
horkos ESO re-point to the `horkos-zot-api` master field (re-created by the
first rotation — until the ceremony mints it the ESO cannot refresh and the
pod keeps the previously synced key, so the pod must not be recycled in
that window). The `zot-cv` identity is retired by this change: its
blueprint user, the `cv-artifacts` group entry and its order-4 zot-app
policy binding, the `blumeops/cv` `cv-artifacts` accessControl grant, and
the `zot-apikey-rotate` entry are gone from the repo here; the live
user, group, and `zot-cv-api` master field are deleted by the ceremony
after sync, with `zot-cv`'s zot API keys revoked first (see the new
"Retiring an identity" section).

**ci-zot cutover (in progress, 2026-09-16).** The base CI push identity
`zot-ci` / `artifact-workloads` is being moved the same way: `ci-zot`
(group `ci-artifacts`) is now additive in the blueprint, in the accessControl
(`**` restated in every per-path block), and in the rotate table. The flip
PR moves `build-container.yaml` to `ci-zot` (its ceremony renames
`blumeops-ci/zot-ci` to `blumeops-ci/ci-zot`, bootstraps the identity, and
rotates), and the following cleanup PR retires `zot-ci` and
`artifact-workloads`.

The task reads the current key from the `Forgejo Secrets` item (blumeops
vault; fields `zot-ci-api`, `ci-zot-api`, `ci-zot-talos-api`, `ci-zot-horkos-api`,
`horkos-zot-api`), mints a new one, proves the new key authenticates, writes the
master copy back, writes the consumer copy — `blumeops-ci/zot-ci`
(`api-key`) for `zot-ci` (and the renamed `blumeops-ci/ci-zot` item for `ci-zot`), the `ZOT_PUSH_API_KEY` Actions secret on
`eblume/talos` / `eblume/horkos` for the per-repo push identities
(`ci-zot-talos` / `ci-zot-horkos`) — and then revokes every other key the
identity holds
(`--keep-others` to skip). Any failure before the writes leaves the old key
valid and its consumer untouched. Key material never touches argv or the
terminal.

For `horkos-zot` the consumer is the master field itself: the horkos
deployment's ESO reads Forgejo Secrets `horkos-zot-api` directly.
Because the horkos deployment has no reloader, the pod must be recycled
after a rotation to pick up the new key.

Rotate before expiry, not after: an expired key cannot mint, and the chain
has to be re-seeded in the browser.

### Bootstrap (first key, or a broken chain)

Needed once per new identity, or when a key expired before anyone rotated it.
This is the one step that stays in the browser: Authentik's OIDC authorize
view requires a login event on the session, and a session created through
API-token impersonation (`POST /api/v3/core/users/<pk>/impersonate/`) has
none, so it bounces to the login flow. Browser impersonation works because it
rides on your own logged-in session.

The identity's user must exist first — the blueprint worker creates it on ArgoCD sync. Check for it in the Authentik admin UI, not with `--dry-run`: for a fresh identity the master field in 1Password does not exist until the first rotation, so `--dry-run` fails on a missing field and says nothing about whether the user exists.


1. In the Authentik admin UI, impersonate the identity (`zot-ci`, `ci-zot`, `ci-zot-talos`, `ci-zot-horkos` or `horkos-zot`)
2. Visit `https://registry.ops.eblu.me` and click "SIGN IN WITH OIDC"
3. Navigate to `https://registry.ops.eblu.me/user/apikey`, generate a key
   (any expiry — it is about to be retired), copy it
4. Stop impersonating, then hand the key to the task from the clipboard:
   ```fish
   pbpaste | mise run zot-apikey-rotate ci-zot-talos --key-stdin
   ```
   `pbpaste` is macOS (gilbert). On ringtail the equivalent is `nix shell nixpkgs#wl-clipboard -c wl-paste -n | mise run zot-apikey-rotate <identity> --key-stdin`.
   That verifies the pasted key, mints the real one, stores it, syncs the
   consumer and revokes the pasted bootstrap key in one step.

**Retiring an identity.** zot keys its API-key table by the identity
string, not by the IdP user: deleting the Authentik user leaves its minted
keys in zot, and a new user with the same username re-attaches them (this
surfaced 2026-09-15 when the new `horkos-zot` publisher inherited the
deleted step-2 user's 2026-09-13 key, a live credential whose 1Password
field was already gone). A retirement must therefore revoke the identity's
zot API keys *before* deleting the Authentik user. Two ways to take the key
listing: `mise run zot-apikey-rotate <identity> --dry-run`, but only *before*
the retire PR merges — that PR is what removes the identity from the rotate
table — or at any time against the raw endpoint with the stored key (`curl
-su '<identity>:<key>' https://registry.ops.eblu.me/zot/auth/apikey`, then
`DELETE .../zot/auth/apikey?id=<uuid>` per key; this is what the 2026-09-16
`zot-cv` retirement used). Any future reuse of a username must start with a
key listing.

## Related

- [[forgejo]] - Container build CI
- [[cluster|Cluster]] - Registry consumer
- [[authentik]] - OIDC identity provider
- [[harden-zot-registry]] - Security hardening guide
- [[service-versions]] - Version tracking for deployed services
