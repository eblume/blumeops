---
title: Tailscale Setup
modified: 2026-10-23
last-reviewed: 2026-10-23
tags:
  - tutorials
  - replication
  - tailscale
---

# Setting Up Tailscale

> **Audiences:** Replicator

This tutorial walks through establishing a Tailscale mesh network as the foundation for your homelab infrastructure.

## Why Tailscale?

Tailscale solves several problems at once:
- **Secure connectivity** - WireGuard-encrypted traffic between all devices
- **No port forwarding** - Devices connect directly through NATs and firewalls
- **MagicDNS** - Human-readable names like `server.tailnet.ts.net`
- **ACLs** - Fine-grained access control between devices

For BlumeOps context, see [[tailscale|Tailscale Reference]].

## Step 1: Create Your Tailnet

1. Sign up at [tailscale.com](https://tailscale.com)
2. Choose your identity provider (Google, Microsoft, GitHub, etc.)
3. Note your tailnet name (e.g., `yourname.ts.net`)

## Step 2: Install on Your Devices

### macOS

```bash
# Option A: GUI app (recommended for desktop Macs)
brew install --cask tailscale
# Then launch Tailscale from Applications and follow the UI

# Option B: Headless CLI (servers/VMs)
brew install tailscale
brew services start tailscale
tailscale up
```

### Linux

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Other Platforms

See [Tailscale Downloads](https://tailscale.com/download) for iOS, Android, Windows, etc.

## Step 3: Verify Connectivity

After installing on two devices:
```bash
tailscale status
# Shows all connected devices

ping <other-device>.yourname.ts.net
# Should work immediately
```

## Step 4: Configure ACLs

Default Tailscale allows all-to-all connectivity. For a homelab, you'll want restrictions.

Edit the policy in the [Tailscale admin console](https://login.tailscale.com/admin/acls) — it has both a JSON editor (the policy is HuJSON, so comments are allowed) and a visual editor. To manage the policy as code instead, keep it in a repo and apply it through the Tailscale policy API or IaC ([[update-tailscale-acls]] shows a worked example).

L4 firewall rules use the modern `grants` schema; the legacy top-level `acls` key is deprecated. Here's an example policy to start from:

```hujson
{
  "groups": {
    "group:admin": ["your-email@example.com"]
  },
  "tagOwners": {
    "tag:homelab": ["group:admin"]
  },
  "grants": [
    // Admins can access everything
    {"src": ["group:admin"], "dst": ["*"], "ip": ["*"]},
    // Homelab servers can reach the NAS
    {"src": ["tag:homelab"], "dst": ["tag:nas"], "ip": ["tcp:443"]}
  ]
}
```

`"ip": ["*"]` means all ports; otherwise list `tcp:PORT` / `udp:PORT` entries.

BlumeOps manages ACLs via Pulumi — see [[tailscale|Tailscale Reference]] for the actual configuration.

## Step 5: Enable MagicDNS

In the Tailscale admin console:
1. Go to DNS settings
2. Enable MagicDNS
3. Optionally add a search domain

Now `ssh server` works instead of `ssh 100.x.y.z`.

## Step 6: Tag Your Devices

Tags enable role-based access control:
```bash
# On your server
sudo tailscale up --advertise-tags=tag:homelab
```

Tags must be defined in ACLs before use.

> **Tip:** If you plan to use subnet routing or Tailscale ProxyGroup Ingress, clients must also run `tailscale up --accept-routes` (or enable "Accept Routes" in the GUI). Without this, advertised routes are invisible to the client.

## What You Now Have

- Encrypted mesh network between all your devices
- DNS names for each device
- Foundation for exposing services securely

## Next Steps

With networking established:
- [[core-services|Set Up Core Services]] - Install Forgejo and optionally a container registry
- [[kubernetes-bootstrap|Bootstrap Kubernetes]] - Your cluster will join the tailnet via the [[tailscale-operator|Tailscale Operator]]

## BlumeOps Specifics

BlumeOps' Tailscale configuration includes:
- Multiple device tags (`homelab`, `nas`, `registry`, `k8s-operator`)
- Group-based access for family members
- SSH access rules with authentication requirements

See [[tailscale|Tailscale Reference]] for full details.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Device won't connect | Check firewall allows UDP 41641 |
| Can't reach other devices | Verify ACLs don't block traffic |
| DNS not resolving | Enable MagicDNS in admin console |
| Tags not applying | Ensure tags defined in ACL policy |
