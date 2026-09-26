---
title: Update Tailscale ACLs
modified: 2026-09-26
last-reviewed: 2026-09-25
tags:
  - how-to
  - tailscale
  - pulumi
---

# Update Tailscale ACLs

How to modify Tailscale access control policies for the tailnet.

## Prerequisites

- Pulumi (installed and pinned by `mise` — see `mise.toml`)
- Access to 1Password blumeops vault (the tasks read the Tailscale OAuth
  client credentials from it)

## Edit the Policy

The ACL policy lives in `pulumi/tailscale/policy.hujson` (HuJSON, so
comments are allowed). Its top-level sections are `groups`, `grants`
(L4 firewall rules), `ssh`, `sshTests` (SSH access rules),
`autoApprovers`, `tagOwners`, and `tests`. The policy uses the modern
`grants` schema — **not** the legacy top-level `acls` key.

`pulumi/tailscale/__main__.py` feeds the file into a `tailscale.Acl`
resource, which **completely overwrites** the tailnet's ACL on every apply
— there is no second source of truth.

### Add a new grant (firewall rule)

```json
{
  "grants": [
    // ... existing grants ...
    {
      "src": ["autogroup:admin"],
      "dst": ["tag:newservice"],
      "ip":  ["tcp:443"]
    }
  ]
}
```

`"ip": ["*"]` means all ports; otherwise list `tcp:PORT` / `udp:PORT`
entries.

### Add a new tag

A new tag must be claimable by someone, so add it to `tagOwners` too
(admins, plus the operator tag if the k8s operator provisions it):

```json
{
  "tagOwners": {
    // ... existing tags ...
    "tag:newservice": ["autogroup:admin", "tag:blumeops"]
  }
}
```

### Add a new group

```json
{
  "groups": {
    // ... existing groups ...
    "group:newgroup": ["user1@example.com", "user2@example.com"]
  }
}
```

## Extend the Tests

The `tests` and `sshTests` sections encode the invariants that make this
policy safe to apply blindly — e.g. the agent pod reaching nothing except
forge and the heph hub, and homelab→homelab SSH for ansible. When you change a grant
or SSH rule, **add or update the matching test entry** so a future
regression fails the preview instead of the tailnet.

## Preview and Apply

```bash
# Preview changes (always do this first)
mise run tailnet-preview

# Apply changes (auto-confirms via --yes)
mise run tailnet-up
```

Both tasks read the OAuth credentials and the Pulumi access token from
1Password and select the
`tail8d86e` stack before running `pulumi preview` / `pulumi up`.

## Verify

Check the Tailscale admin console at https://login.tailscale.com/ to
confirm the access rules, then exercise a new grant from a device in the
source group (or from the `tests` results in the console).

## Troubleshooting

**"Credential expired" error:**
The Tailscale OAuth token has lapsed. Re-run the task; the credentials
come fresh from 1Password each run.

**Changes not taking effect:**
ACL changes apply immediately on `tailnet-up`. If a device isn't following
new rules, try `tailscale down && tailscale up` on that device.

## Related

- [[tailscale]] - ACL reference and current configuration
- [[pulumi]] - Pulumi IaC reference
- [[routing]] - Service routing
