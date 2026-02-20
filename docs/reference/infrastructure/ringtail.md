---
title: Ringtail
modified: 2026-02-19
tags:
  - infrastructure
  - host
---

# Ringtail

Service host and gaming PC. Custom-built PC running NixOS.

## Specifications

| Property | Value |
|----------|-------|
| **Motherboard** | ASUS ROG Crosshair VI Hero (Wi-Fi AC) |
| **CPU** | AMD Ryzen 7 1700X (8-core/16-thread, 3.4 GHz) |
| **RAM** | 32 GB DDR4 (4x8 GB Corsair Vengeance CMK16GX4M2B3200C16, 3200 MT/s DOCP) |
| **GPU** | NVIDIA GeForce RTX 4080 (AD103, 16 GB VRAM) |
| **Monitor** | HP OMEN 27i IPS (2560x1440, 165 Hz, DisplayPort) |
| **Storage (boot)** | Samsung 970 PRO 1TB NVMe |
| **Storage (SATA)** | Samsung 850 EVO 1TB (`/mnt/games`), 850 EVO 500GB (`/mnt/storage1`), 840 PRO 120GB (`/mnt/storage2`) |
| **Peripherals** | Das Keyboard 4, Logitech MX Master 3, 8BitDo Ultimate 2 controller |
| **OS** | NixOS 25.11 (Sway/Wayland) |
| **Tailscale hostname** | `ringtail.tail8d86e.ts.net` |

## Software

Managed declaratively via `nixos/ringtail/configuration.nix`. Home-manager handles ringtail-specific sway/waybar config; chezmoi manages cross-platform dotfiles.

- **Desktop:** Sway (Wayland, Catppuccin Macchiato theme) with waybar and wezterm
- **Browser:** LibreWolf
- **Gaming:** Steam (library on `/mnt/games`), 8BitDo controller via Steam Input
- **Audio:** Edifier R1280DBs (Bluetooth), PipeWire
- **Secrets:** 1Password CLI + GUI (NixOS modules for polkit/setgid integration)
- **Runtimes:** mise manages Node, Python, Rust, .NET; nix-ld enables dynamically linked binaries
- **Dotfiles:** `chezmoi init eblume && chezmoi apply`

## Deployment

```fish
mise run provision-ringtail
```

This updates `flake.lock` via Dagger, verifies the current commit is pushed to forge, then deploys the exact commit via ansible. If the lockfile changed, it stages the file and exits so you can commit and re-run.

## K3s Cluster

Ringtail runs a single-node k3s cluster for native amd64 workloads, registered in [[argocd|ArgoCD]] on indri as `k3s-ringtail`.

- **Disabled components:** Traefik, ServiceLB, metrics-server (minimal footprint)
- **TLS SAN:** `ringtail.tail8d86e.ts.net` (ArgoCD connects via Tailscale)
- **Registry mirrors:** Containerd pulls through Zot on indri (`registry.ops.eblu.me`)
- **Token:** `/etc/k3s/token` (generated on first provision)
- **Kubeconfig:** `/etc/rancher/k3s/k3s.yaml` (world-readable via `--write-kubeconfig-mode=644`)

### Secrets Management

1Password Connect + External Secrets Operator syncs secrets from 1Password to k8s, matching the [[1password|indri pattern]]. Bootstrap credentials (`op-credentials`, `onepassword-token`) are provisioned by Ansible; ArgoCD manages the operator stack.

Sync order: `1password-connect-ringtail` -> `external-secrets-crds-ringtail` -> `external-secrets-ringtail` -> `external-secrets-config-ringtail`

### Workloads

| Workload | Namespace | Notes |
|----------|-----------|-------|
| [[frigate]] | `frigate` | NVR with GPU-accelerated detection (RTX 4080) |
| [[frigate]]-notify | `frigate` | MQTT-to-ntfy alert bridge |
| Mosquitto | `mqtt` | MQTT broker for Frigate events |
| [[authentik]] | `authentik` | OIDC identity provider |
| [[ntfy]] | `ntfy` | Push notification server |
| nvidia-device-plugin | `nvidia-device-plugin` | Exposes GPU to pods via CDI + nvidia RuntimeClass |

### Manual Cluster Registration

After first provision, register the cluster in ArgoCD:

```fish
ssh ringtail 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
  sed 's|127.0.0.1|ringtail.tail8d86e.ts.net|' > /tmp/k3s-ringtail.yaml
set -x KUBECONFIG /tmp/k3s-ringtail.yaml
kubectl get nodes  # verify access
argocd cluster add default --name k3s-ringtail
```

## Systemd Services

### Forgejo Actions Runner

A native Forgejo Actions runner (`ringtail-nix-builder`) runs as a systemd service via the NixOS `services.gitea-actions-runner` module. It builds containers using `nix-build` and pushes them to Zot via `skopeo`.

| Property | Value |
|----------|-------|
| **Label** | `nix-container-builder` |
| **Execution** | Host (no containers) |
| **Token** | `/etc/forgejo-runner/token.env` (provisioned by Ansible) |
| **Service unit** | `gitea-runner-nix_container_builder.service` |
| **Host packages** | bash, coreutils, curl, gawk, git, gnused, jq, nodejs, wget, nix, skopeo |

The runner resolves `<nixpkgs>` from the flake registry at build time. Container trust policy (`/etc/containers/policy.json`) and registry search order (`/etc/containers/registries.conf`) are configured minimally in `configuration.nix` for skopeo — no full `virtualisation.containers` module needed.

## Maintenance Notes

**1Password:** Desktop app must be running for `op` CLI. Use `$mod+Shift+minus` to send to scratchpad.

**NVIDIA:** Proprietary drivers. Sway launched with `--unsupported-gpu` via greetd.

**No TPM:** `systemd.tpm2.enable = false` prevents 90s boot delay.

**RAM speed:** Running at 3200 MT/s via DOCP 1 (BIOS 8902+).

## Related

- [[hosts]] - Device inventory
- [[tailscale]] - Network configuration
