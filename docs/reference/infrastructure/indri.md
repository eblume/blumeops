---
title: Indri
modified: 2026-09-18
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

**Log rotation:** mcquack LaunchAgent logs (~/Library/Logs/mcquack.*.log) are rotated hourly by the mcquack.eblume.logrotate LaunchAgent — any log over 256 MiB is copied to .1 (3 generations kept) and truncated in place; in place because launchd holds O_APPEND fds, so mv-based rotation would leave services writing into the renamed file. The unit and the script are nix-managed (the flake's `launchd.user.agents."mcquack.eblume.logrotate"`, script from the store) under the same label and plist path the ansible role used; the role stays in the play only as the [[provision]] rollback re-writer, skipped by default.

**Metrics collectors:** the four `*-metrics` LaunchAgents (borgmatic, forgejo, jellyfin, zot) that write alloy's node_exporter textfile `.prom` files are nix-managed (the flake's `launchd.user.agents."mcquack.eblume.<name>-metrics"`, scripts from the store) under the same labels and plist paths the ansible roles used; the roles stay in the play only as the [[provision]] rollback re-writers, skipped by default, while the API key files (`~/.forgejo-api-key`, `~/.jellyfin-api-key`) remain controller-side `op` placement.

**Registry (zot):** the zot registry LaunchAgent is nix-managed (the flake's `launchd.user.agents."mcquack.eblume.zot"`) under the same label and plist path the ansible role used; the source-built binary stays at `~/code/3rd/zot` and the config + OIDC credentials stay role-rendered — the role's gate (`zot_ansible_managed`) covers only the plist + load tasks, which stay as the [[provision]] rollback re-write, while the config/credentials rendering and the binary checks still run on every provision. The unit is a real daemon — with it unloaded the registry is down.

**Caddy:** the caddy LaunchAgent is nix-managed (the flake's `launchd.user.agents."mcquack.eblume.caddy"`) under the same label and plist path the ansible role used; the xcaddy-built binary stays at `~/code/3rd/caddy` and the Caddyfile, wrapper script and Gandi token file stay role-rendered — the role's gate (`caddy_ansible_managed`) covers only the plist + load tasks, which stay as the [[provision]] rollback re-write. The unit is a real daemon — it fronts every `*.ops.eblu.me` endpoint and the L4 routes (2222/5433/5434 and the sifaka exporter ports), so with it unloaded all of those are down.

**Forgejo runner:** the forgejo runner LaunchAgent is nix-managed (the flake's `launchd.user.agents."mcquack.eblume.forgejo-runner"`) under the same label and plist path the ansible role used — the first unit in the series whose binary comes from nixpkgs (13.1.0, the flake's pinned nixpkgs rev) instead of a source build; the `~/code/3rd/forgejo-runner` checkout stays on disk only as the [[provision]] rollback re-write's target, and the `config.yaml` (runner token) and the cache prune/sweep agents stay role-rendered — the role's gate (`forgejo_runner_ansible_managed`) covers only the plist + load tasks. The unit is a real daemon: with it unloaded the `indri`-label CI jobs queue, though forge and the other endpoints stay up.

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
  the fish files, `pam.d/sudo_local`, the CA bundle and the ssh client
  config drop-in. `/etc/resolver/ts.net` (tailnet MagicDNS, `nameserver
  100.100.100.100`) is the exception — a real file the indri play writes
  before the switch, not an `environment.etc` entry (nor via
  `services.tailscale`, which would also emit a second tailscaled daemon
  beside the live Homebrew one).
- **Nothing that must work before the Nix Store mounts may live in
  `/etc/static`.** Every `environment.etc` entry is a symlink into the
  store, dangling until Determinate's daemon mounts the volume (tens of
  seconds after boot). Two consumers do not tolerate a dangling link:
  mDNSResponder's `/etc/resolver` scan (skips one and never rescans —
  hence the real resolver file) and sshd's `Include
  /etc/ssh/sshd_config.d/*` (exits 1 on a missing file — every ssh refused
  until the mount). The flake therefore carries
  `services.openssh.hostKeys = []` plus two
  `environment.etc."ssh/sshd_config.d/…".enable = false`
  overrides: no sshd drop-in may be a nix-darwin link. See
  [[provision]] §Reboot test.
- **`/run/current-system` survives reboots.** The first reboot test
  (2026-09-16) found nix-darwin's `org.nixos.activate-system` daemon
  disallowed in Background Task Management, so the symlink was deleted at
  reboot; the verdict was a stale BTM record, not the plist shape —
  `sudo sfltool resetbtm` (run at a Terminal on the box) + reboot cleared it and
  the daemon now runs at boot. The system profile (`/nix/var/nix/profiles/system`) remains the
  durable pointer; the play uses it as the fallback (still needed before
  the first switch). Full record in [[provision]] §Reboot test.
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
source build (`forgejo_mise_bin`).

**The global mise config is declarative.** Indri's global mise config
(`~erichblume/.config/mise/config.toml`) is owned by the indri nix-darwin
flake: `darwin/indri/configuration.nix` declares it as
`environment.etc."mise/config.toml"` (a store symlink at
`/etc/static/mise/config.toml`), and the generation's `postActivation`
fragment symlinks it to `~erichblume/.config/mise/config.toml`
(activation runs as root; the fragment is written so it can never fail the
switch). The file is generation-owned and read-only in practice: change
pins in the flake, not with `mise use` / `mise settings set`. The link
target changes per generation, so `darwin-rebuild --rollback` re-links the
previous generation's config automatically. The config pins
the global go baseline for the source builds (`go` 1.26.7), the host CI
tools the forgejo runner's jobs resolve via the shims (`dagger` 0.21.9,
`prek` 0.4.14, `flyctl` 0.4.87, `argocd` 3.3.12, `actionlint` 1.7.12,
`stylua` 2.4.1, `shellcheck` 0.11.0), `uv` 0.11.7 (the devpi role builds
its venv through the uv shim, and the indri-label CI jobs run `uv run
--script` through it) and `go.set_goroot = false` — an
exported GOROOT breaks Go's `GOTOOLCHAIN=auto` switching, the
auto-switched driver then resolves `compile` from the pinned GOROOT and
dies with `compile: version "goX" does not match go tool version "goY"`.
A pin change is a flake PR; a newly-pinned version is installed on first
shim use (mise auto_install) or by `mise install`. The old
chezmoi-managed file is superseded — forget the dotfiles-side source
(`chezmoi forget ~/.config/mise/config.toml`) so a later `chezmoi apply`
does not replace the symlink with a plain file (that would silently revert
ownership).

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
