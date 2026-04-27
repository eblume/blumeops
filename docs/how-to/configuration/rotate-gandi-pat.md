---
title: Rotate the Gandi PAT
modified: 2026-04-27
last-reviewed: 2026-04-27
tags:
  - how-to
  - dns
  - secrets
---

# Rotate the Gandi PAT

How to rotate the Gandi Personal Access Token. **One PAT** is shared by [[caddy]] (TLS via ACME DNS-01) and Pulumi (DNS records). It lives in 1Password at `op://blumeops/gandi - blumeops/pat`.

## When to rotate

- Every 60 days (Todoist recurring task)
- After any compromise / accidental disclosure
- Whenever Gandi starts rejecting the PAT (see [Debugging](#debugging))

Gandi caps PAT lifetime at 90 days; rotating at 60 leaves a 30-day buffer.

## Prerequisites

- Access to the [Gandi PAT admin console](https://admin.gandi.net/organizations/1db8d76a-f729-11ed-b8d1-00163e94b645/account/pat)
- 1Password (`blumeops` vault)
- Ability to run `mise run provision-indri` (ssh to [[indri]] + 1Password biometric)

## Procedure

### 1. Create a new PAT in Gandi

In the [Gandi PAT console](https://admin.gandi.net/organizations/1db8d76a-f729-11ed-b8d1-00163e94b645/account/pat), create a token:

- **Name:** `blumeops`
- **Expiration:** **90 days** (the max — paired with the 60-day rotation cadence)
- **Permissions:**
  - Manage domain name technical configurations *(required — DNS records and ACME TXT writes)*
  - See and renew domain names

Other permissions are not used.

Copy the new PAT to your clipboard.

### 2. Update 1Password

```bash
op item edit mco6ka3dc3rmw7zkg2dhia5d2m pat="$(pbpaste)" --vault vg6xf6vvfmoh5hqjjhlhbeoaie
```

### 3. Push to indri

The PAT lives in two places: 1Password (read by Pulumi at runtime) and `~/.config/caddy/gandi-token` on indri (read by Caddy at startup). The 1Password edit only updates the first.

```bash
mise run provision-indri --tags caddy
```

This re-fetches the PAT from 1Password, writes it to indri, and restarts Caddy. Caddy will renew any due certificates within minutes.

### 4. Verify

```bash
mise run dns-preview
```

A successful preview confirms Pulumi can use the PAT.

```bash
ssh indri 'tail -50 ~/Library/Logs/mcquack.caddy.err.log' \
  | grep -E "obtained|renew|error"
```

Expect to see no `LiveDNS returned a 403` lines, and either no renewal activity (if no certs were due) or `certificate obtained successfully`.

### 5. Delete the old PAT in Gandi

Return to the Gandi PAT console and delete the previous token.

### 6. Clean up orphan ACME records

Each successful Caddy renewal leaves orphan `_acme-challenge.ops` TXT records in the zone (a bug in `libdns/gandi` v1.1.0 — see the script docstring). Cadence aligns with rotation:

```bash
mise run dns-acme-cleanup --dry-run
mise run dns-acme-cleanup
```

## Debugging

### Caddy logs `LiveDNS returned a 403`

The PAT is invalid (expired, revoked, or insufficient scope). **Gandi returns 403 — not 401 — for an expired PAT**, which can read as a permissions issue. The most common cause is plain expiry. Rotate.

### `mise run dns-preview` returns 403

Same root cause — Pulumi and Caddy share this PAT.

### After a fresh PAT, Caddy still fails

Check that the value on indri matches 1Password:

```bash
diff <(ssh indri 'cat ~/.config/caddy/gandi-token') \
     <(op read 'op://blumeops/gandi - blumeops/pat')
```

If they differ, `mise run provision-indri --tags caddy` was skipped or failed.

Confirm the new PAT works against Gandi directly:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "Authorization: Bearer $(op read 'op://blumeops/gandi - blumeops/pat')" \
  https://api.gandi.net/v5/livedns/domains/eblu.me
```

`200` = healthy. `403` = scope or expiry. `401` = malformed token.

## Related

- [[gandi]] — Gandi reference card
- [[manage-eblu-me-dns]] — DNS records workflow (separate operation, same PAT)
- [[caddy]] — Reverse proxy that uses the PAT for TLS
- [[mise-tasks]] — `dns-acme-cleanup`, `provision-indri`, `dns-preview` reference
