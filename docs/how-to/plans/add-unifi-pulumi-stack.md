---
title: "Plan: Add UniFi Pulumi Stack"
modified: 2026-02-13
tags:
  - how-to
  - plans
  - networking
  - pulumi
---

# Plan: Add UniFi Pulumi Stack

> **Status:** Planned (not yet executed)
> **Blocked by:** 1Password credential setup (API key)

## Background

The UniFi Express 7 (UX7) is the home WiFi router, currently unmanaged. This plan adds a Pulumi stack (`pulumi/unifi/`) to bring it under IaC control, following the same conventions as `pulumi/tailscale/` and `pulumi/gandi/`.

### Why IaC for the Router?

- **Reproducibility** — WiFi networks, firewall rules, and DHCP settings are declared in code
- **Audit trail** — changes go through PR review like all other infrastructure
- **Consistency** — joins the existing Pulumi stacks for Tailscale ACLs and DNS
- **Network segmentation** — declare main/guest/IoT WiFi networks with proper firewall zones

### Ethernet Requirement (Resolved)

The UX7 has one LAN port. Modifying WiFi settings over WiFi would sever the management connection mid-apply. This was resolved by installing:

1. **Two switches** (UniFi Switch Flex Mini recommended) daisy-chained:
   - Switch A by the router: connects UX7, sifaka
   - Switch B on the desk (~12ft cable): connects indri and gilbert
2. **Cat6 Ethernet cables**: one ~12ft run between switches, plus short cables for each device

```
UniFi Express 7 [LAN port]
  └── Switch A (by router/sifaka)
       ├── sifaka (short cable)
       └── ~12ft Cat6 ──→ Switch B (on desk)
                            ├── indri (Cat6)
                            └── gilbert (USB-C adapter)
```

Daisy-chaining is standard Layer 2 networking — no speed loss per device, no subnet impact. The only shared bottleneck is the 1 Gbps uplink between the two switches, which is more than adequate for homelab use. UniFi Flex Minis will appear in the UX7's controller for monitoring and eventual Pulumi management.

## Prerequisites

Before starting the execution session:

- [ ] Purchase 2x UniFi Switch Flex Mini (USW-Flex-Mini)
- [ ] Purchase Cat6 cables: 1x ~12ft, 3-4x short (~3ft)
- [ ] Cable everything up and verify all devices have network connectivity
- [ ] Verify the machine running Pulumi (gilbert) has an active wired Ethernet connection as its default route: `route -n get default` should show a non-Wi-Fi interface
- [ ] **Back up the UX7 configuration** via `https://192.168.1.1` → Settings → System → Backup, and download a `.unf` backup file. Store it safely before making any IaC changes. This provides a rollback path if a provider bug corrupts network or firewall state.
- [ ] Create an API key on the UX7 via `https://192.168.1.1` → Settings → Control Plane → API (preferred over username/password for IaC)
- [ ] Store UniFi API key in 1Password: vault `blumeops`, item `unifi`, category `API_CREDENTIAL`
- [ ] Verify Pulumi CLI version is >= v3.147.0 (`pulumi version`)

## Provider: ubiquiti-community/unifi via `pulumi package add`

We use `pulumi package add terraform-provider ubiquiti-community/unifi` to consume the [ubiquiti-community fork](https://github.com/ubiquiti-community/terraform-provider-unifi) of the UniFi Terraform provider directly from Pulumi. This approach:

- **Generates a local Python SDK** in `./sdks/unifi/` and adds a package reference to `Pulumi.yaml`
- **Supports API key authentication** — cleaner than username/password for IaC
- **Actively maintained** — v0.41.12 (Jan 2026), responsive maintainer, 12 releases since Oct 2025
- **Uses Pulumi Cloud state** — same as existing stacks, free tier
- **No fork/bridge maintenance** — just re-run `pulumi package add` on new provider versions
- **Broader ecosystem** — part of the [ubiquiti-community](https://github.com/ubiquiti-community) org alongside go-unifi, unifi-api, and other tools

### Why Not Other Providers?

| Provider | Why Not |
|----------|---------|
| `pulumiverse_unifi` | Bridges `paultyng/terraform-provider-unifi`, which is abandoned. No API key auth, no newer resource types. |
| `filipowm/unifi` | Maintainer unresponsive since April 2025. Critical bug ([#94](https://github.com/filipowm/terraform-provider-unifi/issues/94)): applying `unifi_network` resources wipes all zone-based firewall rules. Unmerged community fix PRs. |
| `paultyng/unifi` | Abandoned since March 2023. No API key auth, no zone-based firewall. |

### Zone-Based Firewall: Deferred

The ubiquiti-community provider does not yet support zone-based firewall resources ([#77](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/77)). Zone-based firewall rules will be managed manually in the UX7 web UI until provider support lands. This is acceptable because:

- The initial goal is bringing networks, WLANs, and DHCP under IaC
- Network segmentation (which needs firewall zones) is a future phase
- The filipowm provider — the only one with zone firewall support — has a showstopper bug that makes it unusable for this purpose anyway

## Network Segmentation Goals

Once the stack is operational, we plan to configure these network zones:

| Network | VLAN | Subnet | Purpose | Devices |
|---------|------|--------|---------|---------|
| BlumeOps Services | TBD | `192.168.10.0/24` | Infrastructure and services | indri, sifaka, k8s pods |
| User Devices | 1 | `192.168.1.0/24` | Trusted personal devices | gilbert, ringtail |
| Guest | TBD | `192.168.2.0/24` | Guest WiFi, internet-only | Visitors |
| IoT / Appliances | TBD | `192.168.3.0/24` | Smart devices, isolated | Frame TV, dishwasher, etc. |

### Motivation: NFS Share Exposure

The immediate security driver for segmentation is NFS. Currently, sifaka's NFS exports (`/volume1/torrents`, `/volume1/music`, `/volume1/photos`) whitelist `192.168.1.0/24` and `100.64.0.0/10` (Docker NAT). This means **any device on the WiFi** — including IoT appliances, guest devices, or a compromised smart TV — can mount and write to these shares.

After segmentation, NFS exports will be restricted to the BlumeOps Services subnet (`192.168.10.0/24`) and the Docker NAT range (`100.64.0.0/10`). Only indri, sifaka, and k8s pods will have NFS access.

### Zone-Based Firewall Rules

| Source | Destination | Policy |
|--------|-------------|--------|
| BlumeOps Services | Internet | Allow |
| BlumeOps Services | User Devices | Allow (for management, e.g., SSH from ringtail) |
| User Devices | BlumeOps Services | Allow (trusted users need access to services) |
| User Devices | Internet | Allow |
| Guest | Internet | Allow |
| Guest | All other zones | **Block** |
| IoT / Appliances | Internet | Allow |
| IoT / Appliances | User Devices | **Block** (except mDNS for AirPlay/casting) |
| IoT / Appliances | BlumeOps Services | **Allow specific ports** (Jellyfin, Navidrome for streaming) |

### NFS Export Changes

After the network migration, update sifaka's NFS export rules:

| Share | Before | After |
|-------|--------|-------|
| `/volume1/torrents` | `192.168.1.0/24`, `100.64.0.0/10` | `192.168.10.0/24`, `100.64.0.0/10` |
| `/volume1/music` | `192.168.1.0/24`, `100.64.0.0/10` | `192.168.10.0/24`, `100.64.0.0/10` |
| `/volume1/photos` | `192.168.1.0/24`, `100.64.0.0/10` | `192.168.10.0/24`, `100.64.0.0/10` |

This is a manual change in the Synology DSM NFS settings (not managed by Pulumi — sifaka's NFS config is outside the UniFi provider's scope). The k8s PersistentVolume definitions (`argocd/manifests/*/pv-nfs.yaml`) resolve sifaka by hostname and don't need subnet changes.

These will be declared after the initial import is stable.

## Pulumi Stack Structure

Following the conventions of `pulumi/tailscale/` and `pulumi/gandi/`:

```
pulumi/unifi/
├── Pulumi.yaml                  # name: blumeops-unifi, python runtime, uv toolchain
│                                # includes parameterized package reference for ubiquiti-community/unifi
├── Pulumi.home-network.yaml     # Stack config: router_url, site
├── pyproject.toml               # Python >=3.11, pulumi>=3.0.0
├── sdks/unifi/                  # Generated Python SDK from pulumi package add
│   └── ...                      # (auto-generated, committed to repo)
├── __main__.py                  # Main program with safety guard
├── .gitignore                   # .venv/, __pycache__/, *.py[cod]
└── uv.lock                     # Generated by uv sync, committed
```

### Provider Configuration

**Authentication** (via environment variables in mise tasks):

| Variable | Value | Notes |
|----------|-------|-------|
| `UNIFI_API_KEY` | `op read "op://blumeops/unifi/credential"` | API key created in UX7 control plane |
| `UNIFI_API` | `https://192.168.1.1` | No `/api` suffix — SDK auto-discovers `/proxy/network` for UniFi OS |
| `UNIFI_INSECURE` | `true` | UX7 uses a self-signed TLS certificate |

### Safety Guard

The `__main__.py` must fail fast before creating any Pulumi resources if the default network route goes through Wi-Fi. This prevents accidentally modifying WiFi settings while connected over WiFi (which would sever the management connection mid-apply).

The check works as follows:

1. Run `route -n get default` and extract the `interface:` field (e.g., `en5`)
2. Run `networksetup -listallhardwareports` and find which hardware port owns that interface
3. If the hardware port is `Wi-Fi`, abort with an error

This is host-agnostic — it works on both gilbert (where the Ethernet adapter is `AX88179A` on `en5`) and indri (where it's `Ethernet` on `en0`).

## Execution Steps

### Step 1: Create Stack Directory and Install Provider

```fish
mkdir -p pulumi/unifi
cd pulumi/unifi
# Create Pulumi.yaml, pyproject.toml, .gitignore, __main__.py
pulumi package add terraform-provider ubiquiti-community/unifi
# This generates sdks/unifi/ and updates Pulumi.yaml with package reference
pulumi install
uv sync
```

### Step 2: Create Stack Files

Create `Pulumi.yaml`, `Pulumi.home-network.yaml`, `pyproject.toml`, `.gitignore`, and `__main__.py`. The main program should declare:

- **Ethernet safety guard** (verify default route is not Wi-Fi)
- **Default LAN network** resource (corporate, `192.168.1.0/24`, DHCP)
- **WiFi WLAN** resources (commented out initially — need SSID names and IDs from the controller)
- **Exports** for router IP, network ID, subnet

### Step 3: Create Mise Tasks

Create `mise-tasks/unifi-preview` and `mise-tasks/unifi-up` following the pattern from `tailnet-up`/`dns-up`:

```bash
UNIFI_API_KEY=$(op read "op://blumeops/unifi/credential")
export UNIFI_API="https://192.168.1.1"
export UNIFI_INSECURE="true"
```

### Step 4: Initialize Stack

```fish
cd pulumi/unifi
uv sync
pulumi stack init home-network
```

### Step 5: Import Existing Resources

Discover resource IDs from the UniFi controller API or web UI, then import:

```fish
# Import default network
pulumi import unifi:index/network:Network default-lan <network-id>

# Later, import WLANs
pulumi import unifi:index/wlan:Wlan home-wifi <wlan-id>
```

Adjust `__main__.py` resource properties to match the actual controller state until `pulumi preview` shows no diff.

### Step 6: Documentation Updates

- Update `docs/reference/infrastructure/unifi.md` — remove `(planned)` markers, update provider to ubiquiti-community
- Add changelog fragment

### Step 7: Verify

- `mise run unifi-preview` shows no unexpected diffs
- Pre-commit hooks pass
- `docs-check-links` and `docs-check-index` pass

## Known Limitations

- **macOS-specific guard** — the `networksetup` and `route` checks only work on macOS, which is fine since the stack is run from gilbert or indri, both permanently macOS
- **User group ID discovery** — the provider may not expose a `get_user_group` data source. Must be discovered manually from the controller API (`/proxy/network/api/s/default/rest/usergroup`) and hardcoded

## Future Considerations

- **Zone-based firewall rules** — manage via Pulumi once ubiquiti-community adds support ([#77](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/77)). Until then, configure manually in the UX7 web UI.
- **Network segmentation** — depends on zone-based firewall support; see goals above
- **UnPoller** — add Prometheus metrics exporter for UniFi gear, integrates with existing Grafana stack
- **Switch management** — manage the USW-Flex-Minis via the same Pulumi stack once adopted into the UX7 controller
- **Provider updates** — re-run `pulumi package add terraform-provider ubiquiti-community/unifi` to update

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `pulumi/tailscale/__main__.py` | Pulumi program pattern (resources, exports, data sources) |
| `pulumi/gandi/__main__.py` | Config resolution pattern (`pulumi.Config().require()`) |
| `pulumi/tailscale/Pulumi.yaml` | Project definition pattern |
| `pulumi/gandi/Pulumi.eblu-me.yaml` | Stack config pattern |
| `mise-tasks/tailnet-up` | Mise task credential pattern (`op read`) |
| `docs/reference/infrastructure/gandi.md` | Infrastructure reference card pattern |

## Related

- [[hosts]] - Device inventory (UniFi Express 7)
- [[unifi]] - Reference card
- [[power]] - UPS power chain
- [[indri]] - Server connected via Cat6 Ethernet
- [[tailscale]] - Tailnet networking
