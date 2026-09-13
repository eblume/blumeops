---
title: Indri
modified: 2026-09-13
last-reviewed: 2026-05-27
tags:
  - infrastructure
  - host
---

# Indri

Primary BlumeOps server. Mac Mini M1 (2020).

## Specifications

| Property | Value |
|----------|-------|
| **Model** | Mac mini M1, 2020 (Macmini9,1) |
| **CPU / RAM** | 8 cores / 16 GB |
| **Storage** | 2TB internal SSD |
| **macOS** | 15.7.3 (Sequoia) |
| **Tailscale hostname** | `indri.tail8d86e.ts.net` |
| **Tailscale Tag** | `tag:homelab` |
| **Power** | [[power|Battery-backed UPS]] |

## Services Hosted

**Native (via Ansible):**
- [[forgejo]] - Git forge
- [[zot]] - Container registry
- [[jellyfin]] - Media server
- [[borgmatic]] - Backup system
- [[alloy|Alloy]] - Metrics/logs collector
- [[caddy]] - Reverse proxy for `*.ops.eblu.me`
- [[devpi]] - PyPI mirror (LaunchAgent)
- [[hephaestus]] - heph task/context sync hub (LaunchAgent, self-updating)
- [[cv]] - Static CV site, served by Caddy
- [[docs]] - Quartz-built docs site, served by Caddy

**Attached hardware:**
- Pioneer BDR-S13U USB Blu-ray drive — disc archiving via `mise run rip-cd` / `rip-video` ([[rip-a-disc]])

**Kubernetes:** none — indri's minikube cluster was retired 2026-06 ([[retire-minikube]]); all k8s workloads run on [[ringtail]]'s k3s.

**GUI Applications (manual start required):**
- Docker Desktop - Container runtime for the forgejo-runner's job containers (retires in [[retire-minikube]] phase 6)
- Amphetamine - Prevents sleep
- [[automounter]] - Mounts [[sifaka]] SMB shares

## Maintenance Notes

**Sleep prevention:** Uses Amphetamine (App Store) to prevent sleep. If Amphetamine crashes after extended uptime, consider switching to `pmset` or `caffeinate` via ansible.

**Passwordless sudo:** Configured for `erichblume` user (`/etc/sudoers.d/erichblume`) to allow ansible `become: true` without prompts. Acceptable given Tailscale is the trust boundary.

**Log rotation:** mcquack LaunchAgent logs (~/Library/Logs/mcquack.*.log) are rotated hourly by the mcquack.eblume.logrotate LaunchAgent — any log over 256 MiB is copied to .1 (3 generations kept) and truncated in place; in place because launchd holds O_APPEND fds, so mv-based rotation would leave services writing into the renamed file.

## Toolchain

**mise is the toolchain installer, and the mise binary itself is not
managed by this repo.** It comes from a nix-darwin per-user profile
(`/etc/profiles/per-user/erichblume/bin/mise` → nix store), pinned in the
nix-darwin configuration — which lives **outside blumeops** (no darwin
config in the repo; `nixos/` is ringtail only). `~/.config/mise/config.toml`
(global tool pins such as `prek`) is chezmoi-managed, also outside
blumeops.

**Source of truth (fill in once found, on indri):**

```fish
# Name the flake that builds the per-user profile
ls ~/.config/nix-darwin/ && cat ~/.config/nix-darwin/flake.nix
# Or from the profile itself
head -40 /etc/profiles/per-user/erichblume/manifest.nix
darwin-rebuild --list-generations
mise --version
```

Document the answer here: repo/location of the nix-darwin flake, how it is
applied (`darwin-rebuild switch`), and that the mise version is pinned
there. (Not yet located — no SSH path from the talos pod to indri.)

**Staleness guard:** the indri play fails at the top of `pre_tasks` if
`mise --version` is below `indri_mise_min_version` (play vars in
`ansible/playbooks/indri.yml`), so a stale nix-darwin pin is caught at
provision time instead of as a mystery `mise` error inside a role. A
17-month-stale pin (2025.4.11, observed 2026-09-13) made the play's
`go.set_goroot` setting silently rejected and `mise ls` / `mise prune`
error on `prek` (registry entry landed in mise 2025.8.11) — while the
prek shim already existing on PATH kept CI green.

**Bumping mise** (human, on indri):

1. Bump the mise pin in the nix-darwin config (see above) to the version
   ringtail's nixos-26.05 channel currently ships (or current stable).
2. `darwin-rebuild switch`.
3. Verify: `mise --version`; `mise ls` and `mise prune --dry-run` exit 0
   with no registry error; `mise settings get go.set_goroot` → `false`;
   `mise run provision-indri -- --tags forgejo --check --diff` clean.
4. If the old pin left versions behind, prune once and record the
   before/after: `du -sm ~/.local/share/mise/installs` around
   `mise prune`.

**Drift vs ringtail:** ringtail's mise comes from the nixos-26.05
channel (`nixos/ringtail/flake.lock`), so it tracks nixpkgs — as of
2026-09 well above the floor; indri's is a static pin, at 2025.4.11
when this section was written. Target: bring indri to the version
ringtail's channel ships. No deliberate difference is intended; if one
appears, the reason goes here.

## Related

- [[routing]] - Port mappings
- [[cluster]] - Minikube details
- [[automounter]] - SMB share mounting
- [[restart-indri]] - Shutdown and startup procedure
