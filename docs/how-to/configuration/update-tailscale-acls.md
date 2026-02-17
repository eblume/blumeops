---
title: Update Tailscale ACLs
modified: 2026-02-07
tags:
  - how-to
  - tailscale
  - pulumi
---

# Update Tailscale ACLs

How to modify Tailscale access control policies for the tailnet.

## Prerequisites

- Pulumi CLI installed (`brew install pulumi`)
- Access to 1Password blumeops vault (for OAuth credentials)

## Edit the Policy

The ACL policy lives in `pulumi/policy.hujson` (HuJSON format with comments).

Common changes:

### Add a new ACL rule

```json
{
  "acls": [
    // ... existing rules ...
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:newservice:*"]
    }
  ]
}
```

### Add a new tag

```json
{
  "tagOwners": {
    // ... existing tags ...
    "tag:newservice": ["autogroup:admin"]
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

## Preview and Apply

```bash
# Preview changes (always do this first)
mise run tailnet-preview

# Apply changes
mise run tailnet-up

# Skip confirmation prompt
mise run tailnet-up -- --yes
```

## Verify

Check the Tailscale admin console at https://login.tailscale.com/ to confirm changes.

## Common Patterns

### Service-specific access

Grant access to a specific service port:

```json
{
  "action": "accept",
  "src": ["group:users"],
  "dst": ["tag:homelab:8080"]
}
```

### SSH access

```json
{
  "ssh": [
    {
      "action": "check",
      "src": ["autogroup:admin"],
      "dst": ["tag:servers"],
      "users": ["autogroup:nonroot"]
    }
  ]
}
```

### All ports for admins

```json
{
  "action": "accept",
  "src": ["autogroup:admin"],
  "dst": ["*:*"]
}
```

## Troubleshooting

**"Credential expired" error:**
Re-authenticate Pulumi with Tailscale. The OAuth token may need refreshing.

**Changes not taking effect:**
ACL changes are applied immediately. If a device isn't following new rules, try `tailscale down && tailscale up` on that device.

## Related

- [[tailscale]] - ACL reference and current configuration
- [[routing]] - Service routing
