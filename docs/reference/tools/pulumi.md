---
title: Pulumi
modified: 2026-09-30
last-reviewed: 2026-04-02
tags:
  - reference
  - iac
  - pulumi
---

# Pulumi

Infrastructure-as-Code for DNS and Tailscale ACL management. Two independent projects, both using the Python SDK with uv toolchain.

## Projects

| Project | Stack | Source | Manages |
|---------|-------|--------|---------|
| `blumeops-dns` | `eblu-me` | `pulumi/gandi/` | DNS records for `eblu.me` via Gandi LiveDNS |
| `blumeops-tailnet` | `tail8d86e` | `pulumi/tailscale/` | ACL policy, device tags, auth keys |

### DNS (`blumeops-dns`)

Manages `*.ops.eblu.me` wildcard and base records pointing to [[indri]]'s Tailscale IP, plus public CNAME records for services routed via [[flyio-proxy]].

### Tailnet (`blumeops-tailnet`)

Manages the ACL policy (`policy.hujson`), device tags for [[indri]] and [[sifaka]], and auth keys for the Fly.io proxy.

## CLI Patterns

All operations use mise tasks that wrap `pulumi` with the correct stack and working directory:

```bash
# DNS
mise run dns-preview     # Preview DNS changes
mise run dns-up          # Apply DNS changes

# Tailscale
mise run tailnet-preview # Preview ACL/tag changes
mise run tailnet-up      # Apply ACL/tag changes
```

## Authentication

- **Pulumi state**: Pulumi Cloud (app.pulumi.com), which also encrypts stack secrets. Every
  task sources `mise-tasks/_pulumi_env`, which exports `PULUMI_ACCESS_TOKEN` from
  `op://blumeops/Pulumi/access-token` (unless it is already set) and points
  `PULUMI_CREDENTIALS_PATH` at a temp dir removed on exit, since pulumi writes any token it
  uses to `credentials.json`. No host needs a stored `pulumi login`, and none keeps the token.
  Running `pulumi` by hand outside the tasks stores the token in `~/.pulumi/credentials.json`
  unless you set `PULUMI_CREDENTIALS_PATH` the same way.
- **Provider credentials**: The Tailscale OAuth client and the Gandi PAT no longer go through
  the mise tasks. The stacks import Pulumi ESC environments (`eblume/blumeops/tailnet`,
  `eblume/blumeops/dns`), which fetch them from the `pulumi-esc` 1Password vault at open time
  via the `pulumi-esc` service account (read-only on that vault). Rotating a credential in
  1Password takes effect on the next run; no sync step.
- **Pulumi ESC**: Definitions live in `pulumi/esc/`; `mise run pulumi-esc-sync` creates/updates
  the environments and sets the service-account token (read from
  `op://blumeops/pulumi-esc service account/token`) as a secret in `eblume/blumeops/onepassword`.
  If Pulumi Cloud's ESC is down, the stacks don't run anyway (state lives there); if ever lost,
  the environments are re-creatable from `pulumi/esc/`.

### Stack state backup

A daily CronJob (`pulumi-stack-backup` on ringtail) exports both stacks' state
(`pulumi stack export --show-secrets`) to a PVC, which borgmatic ferries off and archives nightly (see [[borgmatic]]).
Config isn't exported: it's in git and ESC. The exports contain plaintext
secret values; the encrypted borg repositories are the compensating control. Restore procedure: [[restore-pulumi-state]].

## Related

- [[manage-eblu-me-dns]] — DNS records workflow
- [[rotate-gandi-pat]] — Rotate the Gandi PAT
- [[update-tailscale-acls]] — ACL editing and Pulumi workflow
- [[gandi]] — DNS hosting
- [[tailscale]] — Tailnet configuration
- [[routing]] — How DNS records map to services
- [[restore-pulumi-state]] — Restore Pulumi stack state from the borg backups
