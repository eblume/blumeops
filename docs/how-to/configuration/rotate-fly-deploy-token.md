---
title: Rotate the Fly.io API Token
modified: 2026-04-30
last-reviewed: 2026-04-30
tags:
  - how-to
  - fly-io
  - secrets
---

# Rotate the Fly.io API Token

How to rotate the Fly.io API token used to deploy [[flyio-proxy]]. The token lives in 1Password at `op://blumeops/fly.io admin/add more/deploy-token` and is consumed by [`mise run fly-deploy`](../../../mise-tasks/fly-deploy) and the `deploy-fly` Forgejo workflow (via the `FLY_DEPLOY_TOKEN` secret).

## When to rotate

- Every 75 days (Todoist recurring task)
- After any compromise / accidental disclosure
- If `fly deploy` starts returning auth errors

Fly.io tokens default to a 20-year expiry, but a short rotation cadence limits the blast radius of an undetected leak. Token expiry is set to **90 days** (longer than the rotation window), leaving a 15-day buffer if a rotation is delayed.

## Scope

Use **`fly tokens create org`**, not `deploy`.

| Scope | What it grants | Practical blast radius (this org) |
|-------|---------------|-----------------------------------|
| `deploy` | Manage one app and its resources | Same single-app surface as `org` for current setup |
| `org` | Manage one org and its resources | Adds: ability to create new apps (billing abuse) and read org-level metadata |
| `readonly` | Read one org | Not enough to deploy |
| Personal access token | Full account | Excessive |

The personal Fly org currently contains a single app (`blumeops-proxy`), so the marginal blast radius of `org` over `deploy` is small. The benefit of `org` is that `fly status` works without a `Metrics token unavailable: ... context canceled` warning. That warning happens because `fly status` always tries to fetch org-level metrics-token info, and an app-scoped `deploy` token can't query the org. The warning is benign but persistent and could mask a real future failure.

If a second Fly app is ever added to this org, reconsider — at that point the marginal scope cost of `org` grows.

## Procedure

### 1. Authenticate flyctl with the current token

```fish
fly auth login
```

(Browser-based. Required to mint a new token, since the existing deploy token can't create tokens.)

### 2. Mint the new token

```fish
fly tokens create org \
  --org personal \
  --name "blumeops-proxy deploy $(date +%Y-%m-%d)" \
  --expiry 2160h
```

(`2160h` = 90 days, paired with the 75-day rotation cadence for a 15-day buffer. Capture the output — it's the only time the token is shown.)

### 3. Update 1Password

```fish
op item edit on5slfaygtdjrxmdwezyhfmqsq 'add more.deploy-token=<paste-new-token>' --vault vg6xf6vvfmoh5hqjjhlhbeoaie
```

### 4. Sync to Forgejo Actions

The `deploy-fly` workflow reads the same token from a Forgejo Actions secret named `FLY_DEPLOY_TOKEN`, populated by the `forgejo_actions_secrets` ansible role:

```fish
mise run provision-indri -- --tags forgejo_actions_secrets
```

### 5. Verify

```fish
mise run fly-deploy
```

A successful deploy confirms the new token works locally. Watch for the metrics-token warning — it should be **absent** with an `org`-scoped token. If still present, the rotation produced a `deploy`-scoped token by mistake.

Then trigger the CI workflow (push a no-op commit touching `fly/`, or dispatch manually) to confirm Forgejo Actions has the new secret.

### 6. Revoke the old token

```fish
fly tokens list
fly tokens revoke <old-token-id>
```

## Debugging

### `fly deploy` returns "unauthorized"

Token is invalid (expired, revoked, or wrong scope). Repeat the procedure.

### `Metrics token unavailable: ... context canceled` after rotation

The new token was created with `deploy` scope, not `org`. Either accept it (cosmetic) or re-mint with `fly tokens create org`.

### Forgejo Actions deploy fails but local works

The Forgejo secret wasn't synced. Re-run `mise run provision-indri -- --tags forgejo_actions_secrets` and confirm the secret value in Forgejo matches 1Password.

## Related

- [[flyio-proxy]] — Service reference card
- [[manage-flyio-proxy]] — Day-to-day operations and Tailscale auth-key rotation (separate 90-day rotation)
- [[expose-service-publicly]] — Full setup architecture
