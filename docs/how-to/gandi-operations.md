---
title: Gandi Operations
modified: 2026-02-08
tags:
  - how-to
  - dns
  - pulumi
---

# Gandi Operations

How to manage DNS records and cycle the Gandi API token.

## Prerequisites

- Pulumi CLI installed (`brew install pulumi`)
- Access to 1Password blumeops vault (for PAT)
- On the tailnet (Pulumi resolves indri's IP via MagicDNS)

## Preview and Apply DNS Changes

```bash
# Preview changes (always do this first)
mise run dns-preview

# Apply changes
mise run dns-up
```

Both tasks fetch the Gandi PAT from 1Password automatically.

To run Pulumi directly:

```bash
export GANDI_PERSONAL_ACCESS_TOKEN=$(op item get mco6ka3dc3rmw7zkg2dhia5d2m --field pat --reveal --vault vg6xf6vvfmoh5hqjjhlhbeoaie)
cd pulumi/gandi
pulumi preview
pulumi up --yes
```

## Cycle the Gandi PAT

The Gandi Personal Access Token has a maximum lifetime of 90 days. Currently set to 30 days as a security compromise, though shorter may be appropriate given infrequent use.

### 1. Create a new PAT

Go to the [Gandi admin console](https://admin.gandi.net/organizations/1db8d76a-f729-11ed-b8d1-00163e94b645/account/pat) and create a new token:

- **Name:** `blumeops-pulumi` (or similar)
- **Expiration:** 30 days (max 90; shorter is fine if you run this rarely)
- **Required permission:** Manage domain name technical configurations
- **Also enable:** See and renew domain names

Copy the new PAT to your clipboard.

### 2. Update 1Password

With the new PAT on your clipboard:

```bash
op item edit mco6ka3dc3rmw7zkg2dhia5d2m pat="$(pbpaste)" --vault vg6xf6vvfmoh5hqjjhlhbeoaie
```

### 3. Delete the old PAT

Return to the Gandi admin console and delete the previous token.

### 4. Verify

```bash
mise run dns-preview
```

A successful preview confirms the new PAT is working.

## Break-Glass Override

If MagicDNS is unavailable and Pulumi can't resolve indri's IP, set the target IP manually. Find indri's current Tailscale IP via `tailscale status` or the admin console:

```bash
export BLUMEOPS_REVERSE_PROXY_IP=<indri-tailscale-ip>
mise run dns-up
```

## Related

- [[gandi]] - DNS configuration reference
- [[caddy]] - Reverse proxy (also uses a Gandi token for TLS)
- [[update-tailscale-acls]] - Similar Pulumi workflow for Tailscale
