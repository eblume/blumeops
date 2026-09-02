---
title: Ringtail
modified: 2026-09-02
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
| **RAM** | 64 GB DDR4 (2x32 GB Crucial CT2K32G4DFD832A in DIMM_A2/B2, Micron dual-rank, JEDEC 3200 CL22 1.2 V, **run at 2400 MT/s**; swapped 2026-09-02, see [[restart-ringtail#RAM-swap checklist]]) |
| **GPU** | NVIDIA GeForce RTX 4080 (AD103, 16 GB VRAM) |
| **PSU** | EVGA SuperNOVA 850 G3 (850 W, 80+ Gold, fully modular; 4080 fed via the 8-pin→12VHPWR adapter) |
| **Monitor** | HP OMEN 27i IPS (2560x1440, 165 Hz, DisplayPort) |
| **Storage (boot)** | Samsung 970 PRO 1TB NVMe |
| **Storage (SATA)** | Samsung 850 EVO 1TB (`/mnt/games`), 850 EVO 500GB (`/mnt/storage1`), 840 PRO 120GB (`/mnt/storage2`) |
| **Peripherals** | Das Keyboard 4, Logitech MX Master 3, 8BitDo Ultimate 2 controller |
| **OS** | NixOS 25.11 (Sway/Wayland) |
| **Tailscale hostname** | `ringtail.tail8d86e.ts.net` |

## Networking

| Property | Value |
|----------|-------|
| **Interface (wired)** | `enp5s0` |
| **IP** | `192.168.1.21/24` (static, set by NixOS scripted networking) |
| **Gateway** | `192.168.1.1` (UX7) |
| **DNS** | `192.168.1.1`, `1.1.1.1` (used as Tailscale's upstream resolvers; `/etc/resolv.conf` is owned by Tailscale's MagicDNS at `100.100.100.100`) |
| **DHCP reservation** | UniFi "Fixed IP" tied to ringtail's MAC; belt-and-suspenders so the UX7 won't lease `192.168.1.21` to anyone else even though ringtail no longer asks for it |
| **Wireless** | `wlp6s0` still managed by NetworkManager as a fallback path |

NetworkManager is enabled but explicitly excluded from managing `enp5s0` via `networking.networkmanager.unmanaged = [ "interface-name:enp5s0" ]`. The wired address is configured by a deterministic `network-addresses-enp5s0.service` oneshot — no daemon, no lease, no renewal.

## Software

Managed declaratively via `nixos/ringtail/configuration.nix`. Home-manager handles ringtail-specific sway/waybar config; chezmoi manages cross-platform dotfiles.

- **Desktop:** Sway (Wayland, Catppuccin Macchiato theme) with waybar and wezterm
- **Browser:** LibreWolf
- **Gaming:** Steam (library on `/mnt/games`), 8BitDo controller via Steam Input
- **Audio:** Edifier R1280DBs (Bluetooth), PipeWire
- **Secrets:** 1Password CLI + GUI (NixOS modules for polkit/setgid integration)
- **Runtimes:** mise manages Node, Python, Rust, .NET; nix-ld enables dynamically linked binaries
- **Dotfiles:** `chezmoi init eblume && chezmoi apply`
- **Shell helpers:** the `myip` fish function (public-IP lookup) is managed declaratively via home-manager `xdg.configFile`. Ringtail's other fish config (`config.fish`, `conf.d/`, most functions) is still hand-placed and not yet under nix — a known drift.

## Deployment

```fish
mise run provision-ringtail
```

This locks new flake inputs via Dagger, verifies the current commit is pushed to forge, then deploys the exact commit via ansible. If the lockfile changed, it stages the file and exits so you can commit and re-run. To update all inputs to latest versions, see [[manage-lockfile]].

Activation runs **detached from the SSH session**, as a transient systemd unit named `blumeops-nixos-rebuild`. A switch restarts `sshd`, `tailscaled` and the network stack, so as a child of the session it could be killed partway through by the teardown it caused. The play starts the unit, reconnects, polls it to completion, and reports systemd's `Result` alongside the unit's journal on failure.

The practical consequence: **losing your connection no longer aborts the switch.** If `provision-ringtail` dies on your end mid-activation, the rebuild is still running on the box — watch it with `ssh ringtail 'journalctl -fu blumeops-nixos-rebuild'` rather than re-running, and let it finish before provisioning again.

## K3s Cluster

Ringtail runs a single-node k3s cluster for native amd64 workloads, registered in [[argocd|ArgoCD]] on indri as `k3s-ringtail`.

- **Disabled components:** Traefik, ServiceLB, metrics-server (minimal footprint)
- **TLS SAN:** `ringtail.tail8d86e.ts.net` (ArgoCD connects via Tailscale)
- **Registry mirrors:** Containerd pulls through Zot on indri (`registry.ops.eblu.me`)
- **Token:** `/etc/k3s/token` (generated on first provision)
- **Kubeconfig:** `/etc/rancher/k3s/k3s.yaml`, root-only via `--write-kubeconfig-mode=600`. ringtail is a multi-user host — the `agent` uid is a co-tenant — so a readable admin kubeconfig is a cluster-admin grant to every local account. See [[agent-workspaces]] §Isolation.

### Secrets Management

1Password Connect + External Secrets Operator syncs secrets from 1Password to k8s, matching the [[1password|indri pattern]]. Bootstrap credentials (`op-credentials`, `onepassword-token`) are provisioned by Ansible; ArgoCD manages the operator stack.

Sync order: `1password-connect-ringtail` -> `external-secrets-crds-ringtail` -> `external-secrets-ringtail` -> `external-secrets-config-ringtail`

### Workloads

| Workload | Namespace | Notes |
|----------|-----------|-------|
| [[frigate]] | `frigate` | NVR with GPU-accelerated detection (RTX 4080) |
| [[frigate]]-notify | `frigate` | Webapi-to-ntfy alert bridge |
| [[authentik]] | `authentik` | OIDC identity provider |
| [[ntfy]] | `ntfy` | Push notification server |
| [[ollama]] | `ollama` | LLM inference with GPU (RTX 4080) |
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

### Snowflake Proxy

A Tor [[snowflake-proxy]] that helps censored users reach the Tor network. Runs as a simple systemd service using the `snowflake` nixpkgs package. The proxy is not a Tor exit node — it only bridges encrypted WebRTC connections to Tor relays.

| Property | Value |
|----------|-------|
| **Service unit** | `snowflake-proxy.service` |
| **Metrics** | `localhost:9999/metrics` (Prometheus) |

### Forgejo Actions Runner

A native Forgejo Actions runner (`ringtail-nix-builder`) runs as a systemd service via the NixOS `services.gitea-actions-runner` module. It builds containers using `nix-build` and pushes them to Zot via `skopeo`.

| Property | Value |
|----------|-------|
| **Label** | `nix-container-builder` |
| **Execution** | Host (no containers) |
| **Token** | `/etc/forgejo-runner/token.env` (provisioned by Ansible) |
| **Service unit** | `gitea-runner-nix_container_builder.service` |

The runner resolves `<nixpkgs>` from the flake registry at build time. Container trust policy (`/etc/containers/policy.json`) and registry search order (`/etc/containers/registries.conf`) are configured minimally in `configuration.nix` for skopeo — no full `virtualisation.containers` module needed.

### Factorio Server

A private Factorio dedicated server (`services.factorio`, `nixos/ringtail/factorio.nix`) — BlumeOps' first externally-shared service. It listens on UDP 34197 with `openFirewall = false`: the port is reachable only over the already-trusted `tailscale0` interface, never the LAN or internet. Named `factorio.ops.eblu.me` via an exact A record (in `pulumi/gandi`) that overrides the `*.ops → indri` wildcard, since the game is UDP and bypasses Caddy.

| Property | Value |
|----------|-------|
| **Service unit** | `factorio.service` |
| **Port** | UDP 34197 (tailnet only) |
| **State / saves** | `/var/lib/factorio` |
| **Access** | guests are *shared* onto ringtail (`autogroup:shared`), granted only `udp:34197` on `tag:factorio` |

Guests are **shared** onto ringtail, never invited as members, so they inherit none of the member-facing services. See [[host-factorio-for-a-guest]] for the onboarding and revocation flow, and [[tailscale]] for the ACL model.

### Heph Spokes

Two `hephd` spokes sync this host to the indri heph hub. They share the version
pin and install machinery (`nixos/ringtail/heph-common.nix`) but hold different
login identities and token stores — hephd sockets/dbs are per-user, and keeping
Erich's access decoupled from the agent kill switches is the point:

| Property | `agent-heph-spoke` | `eblume-heph-spoke` |
|----------|--------------------|---------------------|
| **User** | `agent` | `eblume` |
| **Config** | `agent-heph-spoke.nix` | `heph-eblume.nix` |
| **Identity** | `heph-agents` (revocable) | Erich himself |
| **Token store** | agents 1Password vault (op command store) | `~/.config/heph/hub-token.json` (0600, `--token-file`) |
| **Unit scope** | system | **user** (`systemctl --user`, linger enabled) |

The scope difference is load-bearing: hephd and the `heph` CLI meet at the
default socket path, which depends on `XDG_RUNTIME_DIR`. The agent's sessions
run inside the equally env-less workspace service, so both sides use the
`~/.local/share/heph` fallback; eblume's *interactive* shells resolve
`/run/user/1000/heph/hephd.sock`, so his spoke must run in the systemd user
manager (status/logs: `systemctl --user status eblume-heph-spoke`,
`journalctl --user -u eblume-heph-spoke`).

Both adopt the same hub owner id, so they operate on the same nodes. Each user
gets its own `heph`/`hephd` at `~/.cargo/bin` via a `*-heph-install` oneshot
(timer-fired, off the activation path; the spoke starts via a path unit the
moment the binary lands — see `heph-common.nix` for the quartet). When the
pin moves, the oneshot restarts the matching spoke after the install so the
daemon never lags the installed binary (the agent's oneshot runs as root for
that one step, dropping to `agent` via `runuser` for the cargo work).

**One-time seed for the eblume spoke** (interactive, as eblume on ringtail;
approve in the browser as yourself — no hub-side change needed, you are already
the hub owner):

```sh
~/.cargo/bin/heph auth login \
  --hub-url http://indri.tail8d86e.ts.net:8787 \
  --issuer https://authentik.ops.eblu.me/application/o/heph/ \
  --client-id heph --token-file ~/.config/heph/hub-token.json
```

The agent spoke's seeding is fiddlier — see [[bootstrap-agent-workspaces]] §7.

### MyEVE Heph Sync

An hourly timer (`nixos/ringtail/myeve-heph-sync.nix`) that publishes EVE Online
game state — PI extractor expiry, finished industry jobs, skill-queue
exhaustion, undercut market orders — into heph as tasks under the **MyEVE**
project, so the game's obligations rank alongside the rest of Erich's chores.

| Property | Value |
|----------|-------|
| **Units** | `myeve-heph-sync.service` / `.timer` (**user** scope) |
| **Schedule** | `OnCalendar=hourly`, `RandomizedDelaySec=10m`, `Persistent=true` |
| **Sync logic** | `~/code/personal/myeve/scripts/heph-sync/eve_chores.py` (read from the working tree, not packaged) |
| **Credentials** | `~/code/personal/myeve/secrets/esi-token.json` — an ESI game token, deliberately **not** a blumeops secret |
| **Status / logs** | `systemctl --user status myeve-heph-sync.timer`, `journalctl --user -u myeve-heph-sync` |

User scope for the same reason as the eblume spoke above: the sync shells out to
`heph`, which needs `XDG_RUNTIME_DIR` to find `hephd.sock`. It runs `--apply`
(write mode) unattended; `--commit` is an accepted alias of that flag and has
nothing to do with git.

The unit skips cleanly rather than failing when the `heph` CLI, the myeve
checkout, the ESI token, or the spoke's socket is absent — a missing piece costs
one tick, not a red unit. It does fail loudly if the ESI refresh token is
revoked, which is the intended behaviour: better a failed unit than a silently
stale chore list.

Reconciliation is keyed on a `myeve-key:` line written into each task's
canonical-context doc, and the heph store is the only state — there is no cache
file. Tasks filed by hand under MyEVE carry no key and are never touched. To mute
a chore the game cannot see you have abandoned, push it to **blue** (On Deck);
blue is still `outstanding`, so the reconciler leaves it alone. Marking it `done`
while ESI still reports the obligation just invites the next tick to file it
again.

The Skagit CCE ceramics watch (a user timer that filed a red heph task when a new
ceramics class appeared in the catalog) was retired 2026-09-01 after it caught its
first class. See [[skagit-cce-ceramics-watch]] for the record and the AAR.

## Pinned Service Versions

Versioned services (forgejo-runner, snowflake, k3s) are pinned via a `nixpkgs-services` overlay in `flake.nix`, separate from the rolling `nixpkgs` input. This prevents `nix flake update` from silently upgrading them. The Dagger `flake-update` pipeline excludes `nixpkgs-services` automatically. See [[review-services]] for the upgrade procedure.

## Maintenance Notes

**1Password:** Desktop app must be running for `op` CLI. Use `$mod+Shift+minus` to send to scratchpad.

**NVIDIA:** Proprietary drivers. Sway launched with `--unsupported-gpu` via greetd.

**No TPM:** `systemd.tpm2.enable = false` prevents 90s boot delay.

**RAM speed:** **2400 MT/s, set manually** (Extreme Tweaker → Memory Frequency
= DDR4-2400; Ai Overclock Tuner = Default). The BIOS trains the Crucial kit to
its 3200 JEDEC table on Auto, but the Ryzen 1700X controller is only rated 2400
for two dual-rank DIMMs and Memtest86+ threw errors within minutes at 3200
(68 and climbing, test 2). At 2400 it ran clean through test 6. Do not put the
frequency back on Auto after a BIOS reset without re-running memtest. The
previous 4x8 GB single-rank Corsair kit ran 3200 via DOCP 1 (BIOS 8902+). Full
overnight Memtest86+ burn-in at 2400 still pending (heph task).

## Related

- [[restart-ringtail]] - Shutdown and startup procedure (what goes dark, RAM-swap checklist)
- [[hosts]] - Device inventory
- [[tailscale]] - Network configuration
