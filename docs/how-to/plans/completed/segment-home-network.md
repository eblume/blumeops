---
title: "Plan: Segment Home Network"
modified: 2026-02-24
tags:
  - how-to
  - plans
  - networking
---

# Plan: Segment Home Network

> **Status:** Completed (2026-02-14)
> **Replaces:** [[add-unifi-pulumi-stack]] (abandoned — provider bugs)

## Background

All devices currently share a single flat `192.168.1.0/24` network. This means IoT appliances (Frame TV, dishwasher) and guest devices can reach NFS shares, management interfaces, and all other services on the LAN.

This plan segments the home network into three zones using the UX7 web UI. The IaC approach was abandoned after the `ubiquiti-community/unifi` Terraform provider bricked the network on a no-op update — see [[add-unifi-pulumi-stack]] for details.

### Security Driver: NFS Exposure

Sifaka's NFS exports (`/volume1/torrents`, `/volume1/music`, `/volume1/photos`) whitelist `192.168.1.0/24`. Today, **any device on the WiFi** — including IoT appliances or guest devices — can mount and write to these shares. After segmentation, only Main network devices (192.168.1.0/24) have NFS access. IoT (192.168.3.0/24) and Guest (192.168.2.0/24) are on different subnets and cannot reach NFS even without firewall rules.

## Prerequisites

- [ ] **Back up the UX7 configuration** via `https://192.168.1.1` → Settings → System → Backup. Download the `.unf` backup file before making any changes.
- [ ] Verify all wired devices (indri, sifaka, gilbert) have connectivity
- [ ] Know which devices should go on each network

## Three Networks

| Network | SSID | VLAN | Subnet | Bands | Purpose |
|---------|------|------|--------|-------|---------|
| Main | Radio New Vegas | 1 (default) | 192.168.1.0/24 | All | Trusted devices (indri, sifaka, gilbert, mouse) |
| IoT | (TBD by user) | 3 | 192.168.3.0/24 | 2.4GHz only | Smart devices (Frame TV, appliances) |
| Guest | (TBD by user) | 2 | 192.168.2.0/24 | All | Visitors, internet-only |

## UX7 Configuration Steps

All configuration is done through the UX7 web UI at `https://192.168.1.1`.

### 1. Create IoT Network

Settings → Networks → Create New:

- **Name:** IoT
- **VLAN ID:** 3
- **Gateway/Subnet:** 192.168.3.1/24
- **DHCP:** Enabled, range 192.168.3.6–192.168.3.254

### 2. Create Guest Network

Settings → Networks → Create New:

- **Name:** Guest
- **VLAN ID:** 2
- **Gateway/Subnet:** 192.168.2.1/24
- **DHCP:** Enabled, range 192.168.2.6–192.168.2.254

### 3. Create IoT WLAN

Settings → WiFi → Create New:

- **SSID:** (user's choice)
- **Network:** IoT
- **Band:** 2.4GHz only
- **Security:** WPA2/WPA3

### 4. Create Guest WLAN

Settings → WiFi → Create New:

- **SSID:** (user's choice)
- **Network:** Guest
- **Security:** WPA2/WPA3
- **Guest policies:** Enabled (client isolation)

### 5. Enable mDNS Reflector

Settings → Networks → Global Network Settings:

- Enable **Multicast DNS** — this allows AirPlay/casting discovery across VLANs (Main ↔ IoT)

## Firewall Rules (Zone-Based)

Configured at Settings → Policy Engine → Traffic & Firewall Rules, using Zone-Based Firewall.

All three networks (Default, IoT, Guest) are in the **Internal** zone. Default inter-VLAN policy is **allow**, so we add **block** rules. **Rule ordering matters** — allow rules must come before matching block rules. Rules are combined where the UI supports multiple destinations.

**Reordering rules:** The default Traffic & Firewall Rules view may grey out the Reorder button. Use the **Policy Engine → zone matrix view** (grid icon in the left sidebar under Policy Engine) instead — this view allows reordering.

| # | Name | Action | Source | Destination | Protocol/Port | Notes |
|---|------|--------|--------|-------------|---------------|-------|
| 1 | Allow established/related | Allow | Any | Any | All (Return Traffic only) | Allows return traffic for initiated connections; must be first |
| 2 | IoT → Main streaming allow | Allow | IoT | 192.168.1.99 (indri) | TCP 443, 8096 | Jellyfin direct (8096) and Caddy (443) |
| 3 | Main → IoT AirPlay | Allow | Default | 192.168.3.62 (Frame TV) | TCP+UDP 80,443,554,3689,5000-5001,7000-7001,7100,5353,6001-6002,7010-7011 | AirPlay control and streaming; add more IoT IPs as needed |
| 4 | IoT AirPlay → Main reverse | Allow | 192.168.3.62 (Frame TV) | Default | TCP+UDP 49152-65535 | AirPlay dynamic reverse connections; scoped to TV IP only. May be unnecessary — see note below |
| 5 | Guest → Main,IoT block | Block | Guest | Default + IoT | All | Internet-only isolation, combined into one rule |
| 6 | IoT → Main block | Block | IoT | Default | All | Protect NFS and trusted devices |

### Notes on Firewall Rules

**Rule ordering is critical.** The zone-based policy engine evaluates rules by their index (display order). Allow rules placed after block rules are never reached. When creating new rules, they are appended at the end — use the zone matrix view to reorder them above the block rules.

**AirPlay across VLANs** requires: (1) mDNS reflector enabled on both networks for device discovery, (2) allow rules for AirPlay control ports from Main → TV, and (3) the established/related rule (rule 1) to allow return traffic. Rule 4 (dynamic reverse ports) was added during troubleshooting but may not be necessary — the original failure was caused by rule ordering (allow rules placed after block rules), not missing port rules. If tightening the firewall in the future, try disabling rule 4 and testing whether AirPlay still works with just the established/related rule. The TV IP (192.168.3.62) has a fixed DHCP reservation.

**IoT streaming:** Jellyfin listens on indri:8096 (HTTP). IoT devices (Frame TV) connect directly to `http://192.168.1.99:8096`. Rule 2 allows this specific port; all other Main network access from IoT is blocked by rule 6. The `*.ops.eblu.me` domain resolves to indri's Tailscale IP (100.x.x.x), which is unreachable from non-Tailscale devices, so IoT devices must use the LAN IP directly.

**DHCP reservations:** Indri at 192.168.1.99 and Frame TV at 192.168.3.62 — both have fixed IPs to ensure firewall rules remain valid.

**NFS exports:** No changes needed to sifaka's NFS configuration. The exports whitelist `192.168.1.0/24` — after segmentation, only Main network devices are on that subnet. IoT (192.168.3.0/24) and Guest (192.168.2.0/24) can't reach NFS because they're on different subnets. The firewall rules provide defense-in-depth.

## Future Considerations

- **UnPoller** — add Prometheus metrics exporter for UniFi gear, integrates with existing Grafana stack
- **IaC revisit** — if the ubiquiti-community provider matures and fixes the destructive-update bug, IaC could be reconsidered

## Related

- [[add-unifi-pulumi-stack]] — Previous IaC approach (abandoned)
- [[unifi]] — Reference card
- [[hosts]] — Device inventory
- [[power]] — UPS power chain
