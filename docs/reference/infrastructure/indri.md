---
title: Indri
modified: 2026-09-16
last-reviewed: 2026-09-16
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
| **macOS** | 26.5.2 (Tahoe) |
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

**Sleep prevention:** two layers. The flake sets `power.sleep.computer =
"never"` (`pmset -a sleep 0`), and Amphetamine (App Store) runs in the GUI
session on top. Amphetamine alone was not enough: on 2026-09-16 it
segfaulted after 280 h and, with `pmset sleep 1`, the mini entered
Maintenance Sleep four minutes later — forge, registry and every
`*.ops.eblu.me` route dark until someone touched it. The signature of a
sleep (vs. a crash or a NIC fault): boot time unchanged, `pmset -g log`
shows `Entering Sleep state`, tailscaled logs `LinkChange: major … network
is down`, and `pmset -g assertions` holds no Amphetamine assertion.

**Passwordless sudo:** Configured for `erichblume` user (`/etc/sudoers.d/erichblume`) to allow ansible `become: true` without prompts. Acceptable given Tailscale is the trust boundary.

**Log rotation:** mcquack LaunchAgent logs (~/Library/Logs/mcquack.*.log) are rotated hourly by the mcquack.eblume.logrotate LaunchAgent — any log over 256 MiB is copied to .1 (3 generations kept) and truncated in place; in place because launchd holds O_APPEND fds, so mv-based rotation would leave services writing into the renamed file.

## Nix

indri's system profile is nix-darwin (the `darwin/indri/` flake,
nix-darwin-26.05 on nixos-26.05), applied on top of Determinate Nix — the
apply runbook is [[provision]]:

- **Determinate owns the nix parts.** The daemon, the `/nix` store and the
  nix config (`/etc/nix/nix.custom.conf`) are Determinate's, and the flake
  carries `nix.enable = false` because nix-darwin aborts activation when
  `/usr/local/bin/determinate-nixd` is present. Keep Determinate current
  with its own pkg (`sudo installer -pkg Determinate.pkg -target /`), not
  through nix-darwin.
- **The generation owns the `/etc/static` tree.** bashrc, shells, zshenv,
  the fish files, `pam.d/sudo_local`, the CA bundle and the ssh config
  drop-ins — plus `/etc/resolver/ts.net`, the tailnet MagicDNS resolver,
  written explicitly rather than via `services.tailscale`, which would also
  emit a second tailscaled daemon beside the live Homebrew one.
- **`/run/current-system` does not survive a reboot.** Background Task
  Management refuses nix-darwin's `org.nixos.activate-system` daemon
  (`sfltool dumpbtm`: `Name: sh, Parent: Unknown Developer, Disposition:
  [enabled, disallowed, notified]`), so the symlink exists only between a
  `darwin-rebuild` and the next reboot. The system profile
  (`/nix/var/nix/profiles/system`) is the durable pointer; the play uses
  it as the fallback. Open in [[provision]] §Reboot test.
- **SSH host key.** Remote Login is off; all ssh is Tailscale SSH, which
  serves `/etc/ssh/ssh_host_*_key` when those files exist. nix-darwin
  activation generated them on 2026-09-16, so indri's fingerprint changed
  to `SHA256:liWWi+4w4SbrZyITCkbVmIn+RsHES0hwxvOuWRS6cRA`; a
  known_hosts warning from that date is this, not an intruder.
- **The first switch (2026-09) was one-way.** The old generation
  (system-14, nix-darwin 25.05) aborts its own etc check post-Tahoe and
  would load a second tailscaled, so it was never re-activated; generations
  3–14 were deleted as a safety action once `/etc/static` had moved. From
  the first nix-darwin generation on, rollback is a plain
  `darwin-rebuild --rollback`. The label convention and the fixed
  rollback order for the service migrations live in [[provision]].

## Toolchain
**mise is the toolchain installer, and mise itself comes from Homebrew.**
The indri play ensures `brew install mise` (`Install mise via Homebrew`,
top of `pre_tasks`) and every mise call in the play and the roles goes
through `indri_mise_bin` (`/opt/homebrew/bin/mise`), including the forgejo
source build (`forgejo_mise_bin`). `~/.config/mise/config.toml` (global
tool pins such as `prek`, `go`) is chezmoi-managed, outside blumeops.

**Retired: the old per-user nix-darwin profile.** Before the 2026-09
re-foundation (see [[provision]]), indri ran nix-darwin + home-manager, and
that per-user profile still exists on disk —
`/etc/profiles/per-user/erichblume/bin/mise` → a 2025.4.11 store path.
It is on no PATH the play, the shells or the LaunchAgents use; the forgejo
role was the last thing that hardcoded it (until 2026-09-13), which is
where the stale binary surfaced: `go.set_goroot` silently rejected as an
unknown setting, `mise ls` / `mise prune` erroring on `prek` (registry
entry landed in mise 2025.8.11) — while the prek shim already existing on
PATH kept CI green. Leave the profile alone; the Homebrew mise supersedes
it rather than depending on it.

**Staleness guard:** the play fails at the top of `pre_tasks` if
`indri_mise_bin --version` is below `indri_mise_min_version` (play vars in
`ansible/playbooks/indri.yml`). `state: present` never upgrades, so this is
the only thing that catches drift.

**Bumping mise** (human, on indri):

1. `brew upgrade mise`
2. Verify: `mise --version`; `mise ls` and `mise prune --dry-run` exit 0
   with no registry error; `mise settings get go.set_goroot` → `false`;
   `mise run provision-indri -- --tags forgejo --check --diff` clean.

**Check the dry run before `mise prune`.** Tools the roles install with
`mise install` rather than `mise use` (borgmatic, via
`pipx:borgmatic@{{ borgmatic_version }}`, called by the LaunchAgents through
the `installs/pipx-borgmatic/latest` symlink) have no pin in the global
config. As of 2026-09 prune keeps the newest installed version of such a
tool (2.1.7, the `latest` target) and drops only the older ones, but that
is prune's behaviour, not a guarantee the backups depend on — grep the
`mise prune --dry-run` output for `borgmatic` and confirm `latest` survives
before running it for real.

**Drift vs ringtail:** ringtail's mise comes from the nixos-26.05 channel
(`nixos/ringtail/flake.lock`) and tracks nixpkgs; indri's tracks Homebrew.
Both are current as of 2026-09; no deliberate difference is intended, and
if one appears the reason goes here.

## Related

- [[routing]] - Port mappings
- [[cluster]] - Minikube details
- [[automounter]] - SMB share mounting
- [[provision]] - Provisioning (nix-darwin + ansible)
- [[restart-indri]] - Shutdown and startup procedure
