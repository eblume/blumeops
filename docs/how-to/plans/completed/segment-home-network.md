---
title: "Plan: Segment Home Network"
modified: 2026-02-14
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

| # | Name | Action | Source | Destination | Protocol/Port | Notes |
|---|------|--------|--------|-------------|---------------|-------|
| 1 | Guest → Main,IoT block | Block | Guest | Default + IoT | All | Internet-only isolation, combined into one rule |
| 2 | IoT → Main streaming allow | Allow | IoT | 192.168.1.99 (indri) | TCP 443, 8096 | Jellyfin direct (8096) and Caddy (443) — must be BEFORE the block rule |
| 3 | IoT → Main block | Block | IoT | Default | All | Protect NFS and trusted devices |

### Notes on Firewall Rules

**IoT streaming:** Jellyfin listens on indri:8096 (HTTP). IoT devices (Frame TV) connect directly to `http://192.168.1.99:8096`. Rule 2 allows this specific port; all other Main network access from IoT is blocked by rule 3. The `*.ops.eblu.me` domain resolves to indri's Tailscale IP (100.x.x.x), which is unreachable from non-Tailscale devices, so IoT devices must use the LAN IP directly.

**Indri static IP:** Set a DHCP reservation for indri at 192.168.1.99 in the UX7 client list to ensure the firewall rule remains valid.

**NFS exports:** No changes needed to sifaka's NFS configuration. The exports whitelist `192.168.1.0/24` — after segmentation, only Main network devices are on that subnet. IoT (192.168.3.0/24) and Guest (192.168.2.0/24) can't reach NFS because they're on different subnets. The firewall rules provide defense-in-depth.

## Verification

After applying the configuration:

- [x] From Main device: internet works, can reach all services, can reach sifaka
- [x] From IoT device: internet works, can stream Jellyfin (8096), CANNOT reach sifaka
- [ ] From Guest device: internet works, CANNOT reach any internal service
- [ ] AirPlay/casting from Main to IoT TV works (mDNS reflector)
- [x] All wired devices (indri, sifaka, gilbert) unaffected on default VLAN

## Future Considerations

- **UnPoller** — add Prometheus metrics exporter for UniFi gear, integrates with existing Grafana stack
- **IaC revisit** — if the ubiquiti-community provider matures and fixes the destructive-update bug, IaC could be reconsidered

## Related

- [[add-unifi-pulumi-stack]] — Previous IaC approach (abandoned)
- [[unifi]] — Reference card
- [[hosts]] — Device inventory
- [[power]] — UPS power chain
