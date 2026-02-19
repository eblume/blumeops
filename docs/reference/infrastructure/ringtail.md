---
title: Ringtail
modified: 2026-02-18
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

## Maintenance Notes

**1Password:** Desktop app must be running for `op` CLI. Use `$mod+Shift+minus` to send to scratchpad.

**NVIDIA:** Proprietary drivers. Sway launched with `--unsupported-gpu` via greetd.

**No TPM:** `systemd.tpm2.enable = false` prevents 90s boot delay.

**RAM speed:** Running at 3200 MT/s via DOCP 1 (BIOS 8902+).

## Related

- [[hosts]] - Device inventory
- [[tailscale]] - Network configuration
