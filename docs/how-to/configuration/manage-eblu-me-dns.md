---
title: Manage eblu.me DNS Records
modified: 2026-04-27
last-reviewed: 2026-04-27
tags:
  - how-to
  - dns
  - pulumi
---

# Manage eblu.me DNS Records

How to add, change, and apply DNS records for `eblu.me` via [[pulumi]].

## Prerequisites

- Pulumi CLI installed (`brew install pulumi`)
- 1Password access (`blumeops` vault) — Pulumi reads the Gandi PAT from there
- On the tailnet — Pulumi resolves [[indri]]'s IP via MagicDNS at apply time

## Preview and apply

```bash
mise run dns-preview     # always do this first
mise run dns-up          # apply
```

Both fetch the PAT from 1Password automatically. The Pulumi program is in `pulumi/gandi/`; stack is `eblu-me`.

## Adding a record

Edit `pulumi/gandi/__main__.py` and add a `gandi.livedns.Record(...)`. The stack config (`Pulumi.eblu-me.yaml`) only holds `domain` and `subdomain`; everything else is in the program.

After editing, preview, then apply.

## Break-glass: override the indri target IP

The wildcard `*.ops.eblu.me` is computed from `indri.tail8d86e.ts.net` via MagicDNS at apply time. If MagicDNS is unavailable:

```bash
export BLUMEOPS_REVERSE_PROXY_IP=<indri-tailscale-ip>
mise run dns-up
```

Find the IP via `tailscale status` or the Tailscale admin console.

## Related

- [[gandi]] — Gandi reference card
- [[rotate-gandi-pat]] — Rotate the PAT shared with [[caddy]]
- [[pulumi]] — Pulumi tooling reference
- [[routing]] — Service URLs and routing architecture
