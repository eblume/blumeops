---
id: pulumi
aliases:
  - tailnet-iac
tags:
  - blumeops
---

# Pulumi Tailnet IaC Management Log

Pulumi manages the tail8d86e.ts.net tailnet configuration, including ACLs, tags, and DNS settings.

## Architecture

Two-layer approach:
- **Layer 1 (Pulumi)**: Tailnet-wide config - ACLs, tags, DNS (this card)
- **Layer 2 (Ansible)**: Node-local `tailscale serve` config - see `tailscale_serve` role

## Service Details

- State backend: Pulumi Cloud (https://app.pulumi.com/eblume/blumeops-tailnet)
- Stack: `tail8d86e`
- Config directory: `pulumi/` in blumeops repo
- Policy file: `pulumi/policy.hujson` (HuJSON with comments)

## Authentication

Uses OAuth client stored in 1Password (blumeops vault):
- Client configured with scopes: acl, dns, devices, services
- Auto-applies `tag:blumeops` to IaC-managed resources

## Useful Commands

```bash
# Preview changes
mise run tailnet-preview

# Apply changes
mise run tailnet-up

# View current state
mise run tailnet-preview

# Pass additional args
mise run tailnet-up -- --yes
```

## Making ACL Changes

1. Edit `pulumi/policy.hujson` in the blumeops repo
2. Run `mise run tailnet-preview` to see what will change
3. Run `mise run tailnet-up` to apply
4. Commit and push

## What's Managed

Currently managed by Pulumi:
- ACL policy (`tailscale:index:Acl`)

Can be added later:
- DNS nameservers (`tailscale:index:DnsNameservers`)
- DNS search paths (`tailscale:index:DnsSearchPaths`)
- Tailnet settings (`tailscale:index:TailnetSettings`)

## Log

### Wed Jan 15 2026

- Initial setup with Pulumi + Python
- Imported existing ACL from Tailscale
- State stored in Pulumi Cloud (free tier)
- OAuth authentication via 1Password
