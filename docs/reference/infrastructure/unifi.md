---
title: UniFi
modified: 2026-07-27
last-reviewed: 2026-07-27
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
| **Management** | Web UI only (no IaC) |
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

Three-network segmentation configured manually via UX7 web UI (Feb 2026).

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

Attempted Feb 2026 with the `ubiquiti-community/unifi` Terraform provider via Pulumi. A "no-op" update on the default LAN network reset undeclared properties, bricking the network and requiring a factory reset. The provider ecosystem is too immature for single-device infrastructure.

## API Read Access (Diagnostics)

The `unpoller` API key (1Password item `unpoller`, vault `blumeops`) authenticates
via the `X-API-KEY` header and — as verified Jul 2026 — can read well beyond
metrics: firewall policies, zones, WLAN configs, client tables. Useful endpoints:

```
https://192.168.1.1/proxy/network/integration/v1/sites                       # official integration API
https://192.168.1.1/proxy/network/v2/api/site/default/firewall-policies     # zone firewall policies
https://192.168.1.1/proxy/network/v2/api/site/default/firewall/zone         # zones
https://192.168.1.1/proxy/network/api/s/default/rest/networkconf            # networks (legacy API)
https://192.168.1.1/proxy/network/api/s/default/rest/wlanconf               # SSIDs
https://192.168.1.1/proxy/network/api/s/default/stat/sta                    # active clients
```

Example: `curl -sk -H "X-API-KEY: $(op read 'op://blumeops/unpoller/credential')" <url>`

This key is over-privileged for its purpose (metrics polling); scoping it down is
tracked as a heph task. Read-only GETs are safe; avoid writes — especially `PUT`
on existing objects (the Feb 2026 brick pattern above).

## Firewall Posture (Jul 2026)

All three LAN networks share the **Internal** zone. Custom intra-zone policies, in
evaluation order: allow established/related; IoT → indri streaming pinhole;
Main → IoT AirPlay allows (Frame TV, 192.168.3.62); Guest → Main,IoT block;
IoT → Main block; then zone-default Allow All. Net effect: **Main → IoT is open**,
IoT → Main is blocked apart from pinholes and return traffic. mDNS forwarding is
enabled on Main and IoT, so cross-VLAN discovery works.

Notable IoT clients: Owlet Dream Sock base station (`10:b4:1d:b6:1a:40`,
hostname `espressif`, 192.168.3.250 — DHCP reserved Jul 2026). The IoT SSID is
2.4GHz-only, WPA2-PSK, PMF disabled — keep it that way; IoT devices (Owlet
included) commonly fail on WPA3/PMF/5GHz.

## Monitoring

UniFi metrics are exported to Prometheus via [UnPoller](https://github.com/unpoller/unpoller), running as a k8s deployment in the `monitoring` namespace on indri's minikube (`argocd/manifests/unpoller/`, locally-built image `registry.ops.eblu.me/blumeops/unpoller`). UnPoller polls the UX7 controller API using an API key and exposes metrics on port 9130.

- **Prometheus job:** `unpoller`
- **Metrics prefix:** `unifi_`
- **Credentials:** 1Password item `unpoller` (vault `blumeops`, API key)

## Related

- [[hosts]] — Device inventory
- [[power]] — UPS power chain
- [[indri]] — Primary server (wired connection)
- [[tailscale]] — Tailnet networking
