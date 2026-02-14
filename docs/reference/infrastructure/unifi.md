---
title: UniFi
modified: 2026-02-10
tags:
  - infrastructure
  - networking
---

# UniFi

Home WiFi router and network controller, managed via Pulumi IaC.

## Quick Reference

| Property | Value |
|----------|-------|
| **Model** | UniFi Express 7 (UX7) |
| **LAN IP** | `192.168.1.1` |
| **Management URL** | `https://192.168.1.1` |
| **IaC** | `pulumi/unifi/` (planned) |
| **Stack** | `home-network` (planned) |
| **Power** | Battery-backed via UPS (see [[power]]) |

## What It Does

The UX7 is the home WiFi access point and network gateway. It provides:

- WiFi (main, guest, IoT networks)
- DHCP for `192.168.1.0/24`
- Built-in UniFi controller for managing adopted devices (switches, APs)
- Firewall and traffic management

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

All wired devices share the `192.168.1.0/24` subnet. The two daisy-chained UniFi Switch Flex Minis provide enough ports for all devices while using the UX7's single LAN port.

## Pulumi Configuration (Planned)

The Pulumi program will live in `pulumi/unifi/`:

- `__main__.py` — declares networks, WLANs, and firewall zones
- `Pulumi.home-network.yaml` — stack config (router URL, site)
- `sdks/unifi/` — generated Python SDK from `pulumi package add terraform-provider filipowm/unifi`

Provider: [filipowm/terraform-provider-unifi](https://github.com/filipowm/terraform-provider-unifi) v1.0.0, consumed via `pulumi package add terraform-provider`.

See [[add-unifi-pulumi-stack]] for the full implementation plan.

## Operations

| Task | Command |
|------|---------|
| Preview changes | `mise run unifi-preview` (planned) |
| Apply changes | `mise run unifi-up` (planned) |
| Web management | `https://192.168.1.1` |

## Authentication

The provider uses an API key created in the UX7 control plane (Settings → Control Plane → API). The key is stored in 1Password (`op://blumeops/unifi/credential`) and injected via mise task environment variables.

## Related

- [[add-unifi-pulumi-stack]] - Implementation plan
- [[hosts]] - Device inventory
- [[power]] - UPS power chain
- [[indri]] - Primary server (wired connection required for management)
- [[tailscale]] - Tailnet networking
