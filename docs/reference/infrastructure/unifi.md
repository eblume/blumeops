---
title: UniFi
modified: 2026-02-24
tags:
  - infrastructure
  - networking
---

# UniFi

Home WiFi router and network controller, managed via the UX7 web UI.

## Quick Reference

| Property | Value |
|----------|-------|
| **Model** | UniFi Express 7 (UX7) |
| **LAN IP** | `192.168.1.1` |
| **Management URL** | `https://192.168.1.1` |
| **Management** | Web UI only (no IaC — see [[add-unifi-pulumi-stack]]) |
| **Power** | Battery-backed via UPS (see [[power]]) |

## What It Does

The UX7 is the home WiFi access point and network gateway. It provides:

- WiFi (main, guest, IoT networks)
- DHCP for all network subnets
- Built-in UniFi controller for managing adopted devices (switches)
- Zone-based firewall and traffic management

## Networks

| Network | VLAN | Subnet | Purpose |
|---------|------|--------|---------|
| Main | 1 (default) | 192.168.1.0/24 | Trusted devices (indri, sifaka, gilbert, mouse) |
| Guest | 2 | 192.168.2.0/24 | Visitors, internet-only |
| IoT | 3 | 192.168.3.0/24 | Smart devices (Frame TV, appliances) |

See [[segment-home-network]] for the full segmentation plan and firewall rules.

## Network Topology

```
ISP Modem
  └── UniFi Express 7 [WAN]
       └── [LAN port] ──→ Switch A (by router/sifaka)
            ├── sifaka (Synology NAS)
            └── ~12ft Cat6 ──→ Switch B (on desk)
                                 ├── indri (Mac Mini, primary server)
                                 └── gilbert (USB-C adapter)
```

All wired devices share the default VLAN (192.168.1.0/24). The two daisy-chained UniFi Switch Flex Minis provide enough ports for all devices while using the UX7's single LAN port.

## Operations

| Task | Method |
|------|--------|
| Manage networks/WiFi/firewall | `https://192.168.1.1` web UI |
| Backup configuration | Settings → System → Backup |
| Restore from backup | Settings → System → Backup → Restore |

## Authentication

Local admin account on the UX7. Credentials stored in 1Password (vault `blumeops`). WiFi passphrase stored in 1Password item "Radio New Vegas" (Wireless Router type) in vault `blumeops`.

## Why Not IaC?

Attempted Feb 2026 with the `ubiquiti-community/unifi` Terraform provider via Pulumi. A "no-op" update on the default LAN network reset undeclared properties, bricking the network and requiring a factory reset. The provider ecosystem is too immature for single-device infrastructure. See [[add-unifi-pulumi-stack]] for details.

## Related

- [[segment-home-network]] — Network segmentation plan
- [[add-unifi-pulumi-stack]] — Previous IaC approach (abandoned)
- [[hosts]] — Device inventory
- [[power]] — UPS power chain
- [[indri]] — Primary server (wired connection)
- [[tailscale]] — Tailnet networking
