---
title: Public Family Album Sharing (photos.eblu.me)
modified: 2026-09-04
last-reviewed: 2026-09-04
tags:
  - how-to
  - operations
  - immich
  - fly-io
---

# Public Family Album Sharing (photos.eblu.me)

How the family views curated Immich albums: a `photos.eblu.me` link plus a
password, nothing more. No eblu.me accounts are ever created for guests —
the shared-link surface is the only thing WAN clients can reach, and
curation stays in Immich: you pick the albums to share and delete a link
when the sharing window closes.

## Architecture

```
Family browser
     │  HTTPS
     ▼
Fly.io edge — blumeops-proxy nginx
  (server_name photos.eblu.me, deny-by-default allowlist,
   per-IP rate limits, fail2ban)
     │  Tailscale WireGuard
     ▼
Caddy on indri (photos.ops.eblu.me)
     │
     ▼
Tailscale Ingress photos.tail8d86e.ts.net
     │
     ▼
immich-server — ringtail k3s, namespace immich
```

Public resolution: the `photos` CNAME points at
`blumeops-proxy.fly.dev.` (declared in pulumi, like the other public
hostnames), Fly issues the `photos.eblu.me` Let's Encrypt certificate,
and nginx at the edge tunnels the request back to indri over Tailscale.
Same plumbing as every other public service — see
[[expose-service-publicly]] for the pattern.

## Why shared links only

The public surface is deliberately tiny, and the threat model collapses
the same way it does for the shower guest surface: there is no
credential-accepting endpoint reachable from WAN.

- **No registration** — a shared link *is* the credential. Guests never
  create an account, and nothing on WAN accepts a user credential.
- **Per-link password + expiry** — each link carries its own password and,
  as a habit, an expiry date that closes the window automatically.
- **One-click revoke** — deleting the link kills access instantly, no
  per-user bookkeeping.
- **Login/auth/admin/user API 403 at the edge** — the deny-by-default
  allowlist admits only the smallest route set the share page needs,
  verified against immich v3.0.2's `@Authenticated({ sharedLink: true })`
  routes. Anything else — `/auth/login`, `/api/users/me`,
  `/api/shared-links` — is refused before it ever reaches Immich.

## Creating a link

In the Immich UI (family-facing side):

1. Open the album → **Share** → **shared link**.
2. Set a password and an expiry date (make expiry a habit — most family
   sharing windows are finite).
3. Share the link *and* the password with the family members who need it
   (the password does not travel inside the share URL).

**Revoking** is one click: delete the shared link. The link 404s/errors
immediately; there is no cached copy to worry about.

## [human] setup (one-time)

First time only; idempotent if re-run.

### 1. DNS

```fish
mise run dns-preview
mise run dns-up
```

Adds the `photos` CNAME → `blumeops-proxy.fly.dev.` record (already
declared in `pulumi/gandi/__main__.py`).

### 2. Fly.io certificate

```fish
fly certs add photos.eblu.me -a blumeops-proxy
```

(Also in `mise-tasks/fly-setup` so re-runs of the one-time setup pick it
up.)

### 3. Deploy the edge

The nginx `server` block for `photos.eblu.me` lands with the parallel
`fly/` PR section. Deploy is warrant-gated:

```fish
mise run request-run deploy-fly.yaml <full-sha> --pr <N> \
    -i revision=<full-sha> --why "photos.eblu.me shared-link surface"
```

### 4. Immich external domain

One-time Immich setting: **Admin → Server Settings → External domain** =
`https://photos.eblu.me`. Links generated in the UI (email/share dialogs)
then point at the public name instead of `photos.ops.eblu.me`. This is
persisted in the Immich DB, not a manifest change.

## Verification

From the WAN, the curl matrix:

```
curl -sI https://photos.eblu.me/                                  # 403 with tailnet pointer
curl -sI https://photos.eblu.me/auth/login                        # 403
curl -sI https://photos.eblu.me/api/users/me                      # 403
curl -sI https://photos.eblu.me/api/shared-links                  # 403 (list endpoint, not /me)
curl -sI https://photos.eblu.me/api/server/version                # 200
curl -sI https://photos.eblu.me/share/bogus                       # 200 HTML (app shows "invalid link")
curl -s  'https://photos.eblu.me/api/shared-links/me?key=bogus'   # 401 from immich
curl -sI https://photos.eblu.me/robots.txt                        # 200, Disallow: /
```

Then the real test: open a password-protected link in a private window on
a phone **off Wi-Fi** — password prompt → album grid → full-size photo →
video plays → download works.

Wrong-password bans:

```fish
# fire 16 wrong passwords at a real link, then:
fly ssh console -a blumeops-proxy -C "fail2ban-client status photos-share"
```

Testing from a fixed IP and got banned yourself? Unban it:

```fish
fly ssh console -a blumeops-proxy -C "fail2ban-client set photos-share unbanip <your-ip>"
```

## Edge behavior notes

- **Per-IP rate limits** — general zone 50 r/s (burst 200); the password
  check is far tighter at 3 r/s (burst 5).
- **fail2ban** — jail `photos-share`: 15 fails in 10 minutes → 1 hour ban.
- **Uploads** — allowed at the edge only when the link's own toggle
  permits, capped at 512 m.
- **Video streaming** — proxied unbuffered so playback starts immediately.

## Related

- [[immich]] — the service (Quick Reference table has the public URL)
- [[flyio-proxy]] — the Fly.io edge proxy
- [[expose-service-publicly]] — the full public-exposure pattern
- [[manage-flyio-proxy]] — operating the edge (deploys, shutoff, troubleshooting)
