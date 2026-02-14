---
title: "Plan: Segment Home Network"
modified: 2026-02-14
tags:
  - how-to
  - plans
  - networking
---

# Plan: Segment Home Network

> **Status:** Planned (not yet executed)
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

Configured at Settings → Firewall & Security → Firewall Rules.

UX7 zones correspond to networks. Default inter-VLAN policy is **allow**, so we add **block** rules. **Rule ordering matters** — allow rules must come before matching block rules.

| # | Name | Action | Source | Destination | Protocol/Port | Notes |
|---|------|--------|--------|-------------|---------------|-------|
| 1 | Guest → LAN block | Block | Guest | Main | All | Internet-only isolation |
| 2 | Guest → IoT block | Block | Guest | IoT | All | No cross-zone access |
| 3 | IoT → Main streaming allow | Allow | IoT | Main (indri IP) | TCP 443 | Jellyfin/Navidrome via Caddy — must be BEFORE the block rule |
| 4 | IoT → Main block | Block | IoT | Main | All | Protect NFS and trusted devices |

### Notes on Firewall Rules

**IoT streaming:** Jellyfin (port 8096) and Navidrome bind behind [[caddy]] on indri:443. IoT devices (Frame TV) access media via `https://jellyfin.ops.eblu.me` which resolves to indri's LAN IP. Rule 3 allows IoT → indri:443 only. All other Main network access from IoT is blocked by rule 4.

**NFS exports:** No changes needed to sifaka's NFS configuration. The exports whitelist `192.168.1.0/24` — after segmentation, only Main network devices are on that subnet. IoT (192.168.3.0/24) and Guest (192.168.2.0/24) can't reach NFS because they're on different subnets. The firewall rules provide defense-in-depth.

## Verification

After applying the configuration:

- [ ] From Main device: internet works, can reach all services, can mount NFS
- [ ] From IoT device: internet works, can stream Jellyfin, CANNOT mount NFS
- [ ] From Guest device: internet works, CANNOT reach any internal service
- [ ] AirPlay/casting from Main to IoT TV works (mDNS reflector)
- [ ] All wired devices (indri, sifaka, gilbert) unaffected on default VLAN

## Future Considerations

- **UnPoller** — add Prometheus metrics exporter for UniFi gear, integrates with existing Grafana stack
- **IaC revisit** — if the ubiquiti-community provider matures and fixes the destructive-update bug, IaC could be reconsidered

## Related

- [[add-unifi-pulumi-stack]] — Previous IaC approach (abandoned)
- [[unifi]] — Reference card
- [[hosts]] — Device inventory
- [[power]] — UPS power chain
