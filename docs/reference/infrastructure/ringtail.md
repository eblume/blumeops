---
title: Ringtail
modified: 2026-10-20
last-reviewed: 2026-10-04
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
| **Storage (SATA)** | Samsung 850 EVO 1TB (`/mnt/games`), 850 EVO 500GB (`/mnt/storage1`) |
| **Peripherals** | Das Keyboard 4, Logitech MX Master 3, 8BitDo Ultimate 2 controller |
| **OS** | NixOS 26.05 (Sway/Wayland) |
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
- **Audio:** Edifier R1700BTs (Bluetooth), PipeWire — `nixos/ringtail/audio.nix`. The speakers are physically wired left/right swapped, so a WirePlumber smart filter crosses the channels in front of their sink; the `edifier-autoconnect` user unit reconnects them every 30 s while disconnected (`systemctl --user stop edifier-autoconnect` to pair them elsewhere)
- **Secrets:** 1Password CLI + GUI (NixOS modules for polkit/setgid integration)
- **Runtimes:** mise manages Node, Python, Rust, .NET; nix-ld enables dynamically linked binaries
- **Dotfiles:** `chezmoi init eblume && chezmoi apply`
- **Shell helpers:** the `myip` fish function (public-IP lookup) is managed declaratively via home-manager `xdg.configFile`. Ringtail's other fish config (`config.fish`, `conf.d/`, most functions) is still hand-placed and not yet under nix — a known drift.

## Deployment

Changes ship as a blumeops PR: merging to main with a diff touching
`nixos/ringtail/**` makes `ringtail-rebuild.yaml` auto-apply the merge commit
via the detached `ringtail-apply@<sha>` unit ([[auto-apply]]) — there is no
manual deploy step. To add a new nix input, run `nix flake lock` yourself
first (see [[manage-lockfile]]); the lockfile travels in the same PR.

The human break-glass path — a box too broken to reach the merge machinery —
is the local apply documented in [[disaster-recovery]]: the one-time blumeops
clone into `/etc/blumeops`, then a direct `nixos-rebuild switch` on a fresh host (no blumeops generation yet, so no unit) or the `ringtail-apply@<sha>` unit on a host that already runs one. On-host
secret files (the forgejo-runner registration tokens, `/etc/k3s/token`,
`/etc/agents/op-token`) are not part of any deploy: they are declared in
`nixos/ringtail/secrets.json` and owned by the human-run
`mise run seed-secrets ringtail` ([[seed-secrets]]).

Activation runs **detached from the launching session**, as a transient
systemd unit named `blumeops-nixos-rebuild`. A switch restarts `sshd`,
`tailscaled` and the network stack, so the rebuild must live outside the
apply's session lifetime: the `ringtail-apply@` wrapper starts the unit with
`systemd-run --no-block` and streams its journal into
`/var/log/ringtail-apply/<sha>.log`.

The practical consequence: **losing the apply's connection no longer aborts
the switch.** If the applying process dies mid-activation, the rebuild is
still running on the box — watch `/var/log/ringtail-apply/<sha>.log` (or
`ssh ringtail 'journalctl -fu blumeops-nixos-rebuild'`) rather than
re-applying, and let it finish before applying again.

## K3s Cluster

Ringtail runs a single-node k3s cluster for native amd64 workloads. [[argocd|ArgoCD]] runs in-cluster on this k3s and manages it in-place — every Application targets the in-cluster `https://kubernetes.default.svc`.

- **Disabled components:** Traefik, ServiceLB, metrics-server (minimal footprint)
- **TLS SAN:** `ringtail.tail8d86e.ts.net` — set in k3s `extraFlags` so the API server is reachable over the tailnet at `https://ringtail.tail8d86e.ts.net:6443`
- **Graceful Node Shutdown:** kubelet drains the pods on host reboot/poweroff (`shutdownGracePeriod: 60s`, logind `InhibitDelayMaxSec: 60s`) — the 2026-09-08 fix for the ~10-min reboot holds, see [[restart-ringtail]] and eblume/blumeops#906.
- **Registry mirrors:** Containerd pulls through Zot on indri (`registry.ops.eblu.me`)
- **Token:** `/etc/k3s/token` (generated on first provision)
- **Kubeconfig:** `/etc/rancher/k3s/k3s.yaml`, root-only via `--write-kubeconfig-mode=600`. ringtail is a multi-user host — the `agent` uid is a co-tenant — so a readable admin kubeconfig is a cluster-admin grant to every local account. See [[agent-workspaces]] §Isolation.

### Secrets Management

1Password Connect + External Secrets Operator syncs secrets from 1Password to k8s, matching the [[1password|indri pattern]]. The bootstrap credentials (`op-credentials`, `onepassword-token`) are seated once by step 7 of the ArgoCD bootstrap runbook (`argocd/manifests/argocd/README.md`, see [[argocd]]); ArgoCD manages the operator stack.

Sync order: `1password-connect-ringtail` -> `external-secrets-crds-ringtail` -> `external-secrets-ringtail`. The `ClusterSecretStore` is a resource of the `external-secrets-ringtail` app (`argocd/manifests/external-secrets/cluster-secret-store.yaml`).

### Notable workloads

| Workload | Namespace | Notes |
|----------|-----------|-------|
| [[frigate]] | `frigate` | NVR with GPU-accelerated detection (RTX 4080) |
| [[frigate]]-notify | `frigate` | Webapi-to-ntfy alert bridge |
| [[authentik]] | `authentik` | OIDC identity provider |
| [[ntfy]] | `ntfy` | Push notification server |
| [[ollama]] | `ollama` | LLM inference with GPU (RTX 4080) |
| nvidia-device-plugin | `nvidia-device-plugin` | Exposes GPU to pods via CDI + nvidia RuntimeClass |

This is a subset — the full inventory is the 36 ArgoCD Applications in `argocd/apps/`.

### Borgmatic dump endpoint

Indri's nightly borgmatic backs up ringtail's k8s and local-path-PV data through a dedicated `borgmatic` system user: `sudo /etc/borgmatic/borgmatic-dump <name>` runs one dump from the script's fixed table (mealie, horkos, navidrome, audiobookshelf, the two pulumi stack-state ferries, talos-data, paperless-media) and streams it to stdout. The script and table live in the flake (`nixos/ringtail/borgmatic-dump.sh`); the sudo rule grants only that command as root, no password, and the script itself accepts exactly one argument — a dump name from the table — rejecting anything else. This is the receiving half of eblume/blumeops#1484: indri's borgmatic role SSHes `borgmatic@ringtail` with its dedicated key (IdentitiesOnly, forced command) and sends only the dump name; the key's `restrict` + forced command keep the session to that one call. The key is additionally pinned to indri's Tailscale IP by `from="100.98.163.89"` — only indri can use it, not anything else that can reach the sshd. If indri is re-IPed on the tailnet, update the key line in `nixos/ringtail/configuration.nix`.

## Systemd Services

### Snowflake Proxy

A Tor [[snowflake-proxy]] that helps censored users reach the Tor network. Runs as a simple systemd service using the `snowflake` nixpkgs package. The proxy is not a Tor exit node — it only bridges encrypted WebRTC connections to Tor relays.

| Property | Value |
|----------|-------|
| **Service unit** | `snowflake-proxy.service` |
| **Metrics** | `0.0.0.0:9999` (Prometheus, scraped by the `alloy-ringtail` app) |

### Forgejo Actions Runner

Three native Forgejo Actions runners (`ringtail-nix-builder-{blumeops,horkos,talos}`) run as systemd services via the NixOS `services.gitea-actions-runner` module. They build containers using `nix-build` and push them to Zot via `skopeo`.

| Property | Value |
|----------|-------|
| **Label** | `nix-container-builder` |
| **Execution** | Host (no containers) |
| **Token** | `/etc/forgejo-runner/{priv,nix-builder-blumeops,nix-builder-horkos,nix-builder-talos}.env` (seeded by `mise run seed-secrets ringtail`) |
| **Service unit** | `gitea-runner-nix_container_builder_{blumeops,horkos,talos}.service` |

The registration is repo-scoped (blumeops#1358), one daemon per registered repo sharing the `nix-container-builder` label (capacity 1 each), and the module re-registers an instance automatically when its token file changes.

The runner resolves `<nixpkgs>` from the flake registry at build time. Container trust policy (`/etc/containers/policy.json`) and registry search order (`/etc/containers/registries.conf`) are configured minimally in `configuration.nix` for skopeo — no full `virtualisation.containers` module needed.

A second runner, `ringtail-priv-runner` (label `priv:host`), hosts the dispatch-only privileged workflow jobs — a sandboxed systemd service running as the static user `horkos-runner`, so a compromised job touches the sandbox rather than the forge owner's account. See [[warrant-approval-gated-runs]].

### Factorio Server

A private Factorio dedicated server (`services.factorio`, `nixos/ringtail/factorio.nix`) — BlumeOps' first externally-shared service. It listens on UDP 34197 with `openFirewall = false`: the port is reachable only over the already-trusted `tailscale0` interface, never the LAN or internet. Named `factorio.ops.eblu.me` via an exact CNAME (in `pulumi/gandi`) to ringtail's MagicDNS name, which beats the `*.ops` wildcard. Deliberately *not* an A record: the game is UDP and bypasses Caddy, so DNS must land on ringtail directly, and a shared node gets a different `100.x` address in each guest's tailnet — a pinned A record would publish one owner-tailnet IP that guests can't route.

| Property | Value |
|----------|-------|
| **Service unit** | `factorio.service` |
| **Port** | UDP 34197 (tailnet only) |
| **State / saves** | `/var/lib/factorio` |
| **Access** | guests are *shared* onto ringtail (`autogroup:shared`), granted only `udp:34197` on `tag:factorio` |

Guests are **shared** onto ringtail, never invited as members, so they inherit none of the member-facing services. See [[host-factorio-for-a-guest]] for the onboarding and revocation flow, and [[tailscale]] for the ACL model.

### Heph Spokes

Two `hephd` spokes sync this host to the indri heph hub. They hold different
login identities and token stores — hephd sockets/dbs are per-user, and keeping
Erich's access decoupled from the agent kill switches is the point. Shared
plumbing (hub/OIDC endpoints, the session shims, the popover launcher) lives
in `nixos/ringtail/heph-common.nix`:

| Property | `agent-heph-spoke` | `eblume-heph-spoke` |
|----------|--------------------|---------------------|
| **User** | `agent` | `eblume` |
| **Config** | `agent-heph-spoke.nix` | `heph-eblume.nix` |
| **Identity** | `talos-heph` (revocable) | Erich himself |
| **Token store** | agents 1Password vault (op command store) | `~/.config/heph/hub-token.json` (0600, `--token-file`) |
| **Unit scope** | system | **user** (`systemctl --user`, linger enabled) |

The scope difference is load-bearing: hephd and the `heph` CLI meet at the
default socket path, which depends on `XDG_RUNTIME_DIR`. The agent's sessions
run inside the equally env-less workspace service, so both sides use the
`~/.local/share/heph` fallback; eblume's *interactive* shells resolve
`/run/user/1000/heph/hephd.sock`, so his spoke must run in the systemd user
manager (status/logs: `systemctl --user status eblume-heph-spoke`,
`journalctl --user -u eblume-heph-spoke`).

Both adopt the same hub owner id, so they operate on the same nodes. Both
spokes' `heph`/`hephd` come from the nix-store package built from the `hephaestus`
flake input (see [[agent-workspaces]]), so both are part of the toplevel: the
agent spoke starts at boot like any other service, and the eblume spoke is a
user service started by the user manager (linger enabled), so it starts at
boot too. The session `heph` bins are home-manager shims to the store bin dir,
and the sway quick-capture popover execs the store `heph-quickadd` directly.
A one-shot (`heph-cargo-bin-cleanup`) removes the pre-switch cargo-installed
heph binaries from both users' `~/.cargo/bin` at each boot (a no-op once they
are gone), so no shell can shadow the store bins with them.
When the pin moves, the nixos switch restarts both spokes on unit-file change:
the agent's system unit, and eblume's user unit — since nixos-25.11 the switch
(switch-to-configuration-ng) restarts changed user units for every user whose
manager is running, and lingering keeps user@1000 up.

**One-time seed for the eblume spoke** (interactive, as eblume on ringtail;
approve in the browser as yourself — no hub-side change needed, you are already
the hub owner):

```sh
heph auth login \
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

Versioned services (forgejo-runner, snowflake, k3s, kubectl) are pinned via frozen inputs in `flake.nix` — `nixpkgs-services` for forgejo-runner, k3s, and kubectl, and a dedicated `nixpkgs-snowflake` for snowflake (eblume/blumeops#1702) — separate from the rolling `nixpkgs` input. This prevents `nix flake update` from silently upgrading them. The Ringtail Flake Update workflow (native nix on the `nix-container-builder` runner) excludes the pinned inputs automatically. The Ringtail Flake Check workflow builds the flake's `system` on that same runner whenever `nixos/ringtail/` (or the workflow file) changes - a CI check on the same nix the `ringtail-apply` unit rebuilds with. See [[review-services]] for the upgrade procedure.

## Maintenance Notes

**1Password:** Desktop app must be running for `op` CLI. Use `$mod+Shift+minus` to send to scratchpad.

**NVIDIA:** Proprietary drivers. greetd greets via ReGreet under cage (a Wayland compositor): it holds the DRM master and suspends fbcon, so loglevel-7 kernel text for netconsole can't paint the login screen. Sway starts with `--unsupported-gpu` baked into both sway wrappers (`programs.sway.extraOptions` and home-manager's `wayland.windowManager.sway.extraOptions`), so the stock wayland-sessions entry ReGreet launches needs no patching.

**No TPM:** `systemd.tpm2.enable = false` prevents 90s boot delay.

**Disks:** if a drive runs short on space again, the next step is a new disk — file a heph task for Erich — not a designed migration (2026-10-24: storage2, the empty 120 GB 840 PRO, was retired as too small for scratch — eblume/blumeops#1888).

**RAM speed:** **2400 MT/s, set manually** (Extreme Tweaker → Memory Frequency
= DDR4-2400; Ai Overclock Tuner = Default). The BIOS trains the Crucial kit to
its 3200 JEDEC table on Auto, but the Ryzen 1700X controller is only rated 2400
for two dual-rank DIMMs and Memtest86+ threw errors within minutes at 3200
(68 and climbing, test 2). At 2400 it is clean: the full overnight Memtest86+
burn-in on 2026-09-05→06 passed (PASS banner, 0 errors, several passes; the kit
is keepers). Do not put the frequency back on Auto after a BIOS reset without
re-running memtest. The previous 4x8 GB single-rank Corsair kit ran 3200 via
DOCP 1 (BIOS 8902+). Plan: a Zen 3
CPU upgrade (this BIOS supports Ryzen 5000) should let the kit run its 3200
JEDEC table — set Memory Frequency back to Auto and re-memtest then.

**Unclean resets 2026-09-10 (beyla BPF kernel panic):** two hard resets in one
day, both the same kernel panic — a NULL-pointer dereference at address
`0x21` inside `bpf_prog_…_obi_protocol_tcp+0x5aae`, reached through
`uprobe_notify_resume` → `uprobe_dispatcher` → `__uprobe_perf_func`. That is
[Beyla](https://github.com/grafana/beyla)'s eBPF uprobe in `alloy-tracing`
firing on a process it had hooked; `kernel.panic_on_oops=1` and
`kernel.panic=10` turn the oops into a reboot rather than a hang. Each panic
left an EFI pstore archive under `/var/lib/systemd/pstore/`, which is how the
cause was found in minutes (see [[restart-ringtail#After an unclean reboot]]).

| Reset | Panicking task | pstore | What ran just before |
|-------|----------------|--------|----------------------|
| 11:43:12 PDT | `tailscaled`, PID 3401628 (the talos v0.4.106 sidecar, started 11:42:44) | `1789065801` | Talos image roll — a *fresh* process attached before its pod metadata resolved |
| 15:40:37 PDT | `postgres`, UID 26 (a CloudNativePG backend) | `1789080043` | Nothing: the v0.4.109 pods had been up 15 minutes and k3s logged no pod start since. A forked child of an already-probed executable is enough |

Ruled out: no OOM-killer activity in either boot, no systemd shutdown
markers, kernel 6.18.49 on both sides, no flake or nixpkgs change in the
window, and the box is on the UPS ([[power]]). A byte-identical BPF fault
signature twice is software, so the PSU and thermals were never opened.

The 15:40 reset landed eleven minutes into the ringtail-rebuild for the heph
v1.10.4 pin (run 3023, `7bc03399`) while `eblume-heph-install` was compiling
(`Compiling chrono v0.4.44` is the last journal line). The compile was a
bystander — it did not cause the panic — but it is why the switch was left
unfinished and needed re-run 3024. eblume/blumeops#1014 took the cargo
install off the activation path for good (Heph Spokes above); the first
switch after it (run 3187, 29 s, no cargo) left both install services
`active (exited)` from the pre-change instance with the timers showing no
next elapse — a one-time `systemctl stop` + `start` of the two services, or
the next boot, cleared that (both install services are since retired with
the store-package switch, eblume/blumeops#1541).

Beyla was disabled the same evening (eblume/blumeops#984, 18:56 PDT) and
re-enabled on 2026-09-11 at 12:07 PDT under eblume/blumeops#999: beyla
v3.33.0, which carries the upstream uprobe-preemption fix, behind a
16-namespace allowlist. The re-enable canary and its criteria live in
eblume/blumeops#983; the full incident thread is eblume/blumeops#1003.

**GPU husk reaper** (eblume/blumeops#1151): after a hard reboot, kubelet
readmits the node's bound pods before the `nvidia-device-plugin` DaemonSet has
re-registered `nvidia.com/gpu`, so each GPU workload (Frigate, Immich ML,
ollama) fails allocation and leaves a permanent `UnexpectedAdmissionError`
husk — the Deployment creates a `Running` replacement in ~100 s, but kubelet
never reaps the Failed pod (upstream kubelet behaviour; the real fix —
deferred pod admission (kubernetes/kubernetes PR #139959) — was still
unmerged as of the 1.37 cycle). A
reaper CronJob in the `nvidia-device-plugin` app
(`argocd/manifests/nvidia-device-plugin/cronjob-gpu-husk-reaper.yaml`) deletes
Failed pods that request `nvidia.com/gpu` every 10 minutes, so the husks are
gone ~10 min after boot with no manual `kubectl delete pod`.

## Related

- [[restart-ringtail]] - Shutdown and startup procedure (what goes dark, RAM-swap checklist)
- [[hosts]] - Device inventory
- [[tailscale]] - Network configuration
