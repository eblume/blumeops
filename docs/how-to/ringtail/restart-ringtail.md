---
title: Restart Ringtail
modified: 2026-09-02
last-reviewed: 2026-09-02
tags:
  - how-to
  - operations
  - ringtail
---

# Restart Ringtail

How to safely shut down, work on, and restart [[ringtail]] — the NixOS host
that runs the entire k3s cluster and doubles as the gaming PC.

Ringtail is a single node with no failover, so a shutdown is a full
Kubernetes outage. The procedure itself is short (systemd does the graceful
part); the value of this page is knowing **what goes dark**, what to check
first, and what to verify afterwards.

## What goes dark

Everything in [[cluster]] — see `argocd/apps/` for the full list. The ones
that change how you operate during the outage:

| Service | Consequence while down |
|---------|------------------------|
| [[argocd]], [[horkos]] | No syncs, no warrant dispatch. Agent `request-run` calls queue and stall. |
| Grafana, Prometheus, Loki, [[ntfy]] | **Monitoring is blind and nothing will alert**, including about ringtail itself. `mise run agent-health` fails rather than reporting. |
| [[authentik]] | SSO is down: Grafana, ArgoCD, heph hub login, anything OIDC-fronted. Already-issued sessions on indri services keep working. |
| CloudNativePG databases | Immich, Paperless, Mealie, Miniflux, TeslaMate etc. lose their Postgres. CNPG shuts Postgres down cleanly on SIGTERM; no data loss from a normal poweroff. |
| [[frigate]] | Recording gap and no detections for the duration. |
| [[ollama]], [[talos]] | LLM inference and the agent runtime are offline; any agent session in flight dies. |
| Forgejo runner (`ringtail-nix-builder`) | In-flight container builds fail; the job shows as failed on forge and needs a re-run. |
| Heph spokes | Both spokes stop syncing; the hub on [[indri]] is unaffected. They catch up on boot. |
| Factorio | Guests are disconnected. |

Indri, sifaka, and the Fly proxy are unaffected. Forge, Zot, Caddy, Jellyfin
and the heph hub stay up. Public `*.eblu.me` routing stays up but every
service that is backed by ringtail returns errors.

## Prerequisites

- SSH access to ringtail, or a seat at the console.
- Tailscale connected (if working remotely).

## Shutdown procedure

### 1. Pre-checks

Nothing is *required* here — systemd stops everything gracefully — but each of
these turns a surprise into a non-event:

```fish
mise run runner-logs                 # no build in progress on the ringtail runner
mise run verify-runs                 # no horkos-dispatched run in flight
argocd app list | grep -v Synced     # nothing mid-sync (pin/unpin later if so)
ssh ringtail 'sudo k3s kubectl get pods -A | grep -v -E "Running|Completed"'
```

If an agent session is active (a `heph` task in progress, a PR being built),
let it finish or accept that it dies.

If you are doing this for a **kernel update** (see [[manage-lockfile]]), the
pending generation is already activated and a plain reboot is all that is
needed.

### 2. Power off

```fish
ssh ringtail 'sudo systemctl poweroff'
```

Or `sudo reboot` if there is no hardware work to do. From the console, the
same commands in a terminal — Sway has no power menu configured.

This is the whole graceful shutdown: systemd stops `k3s.service`, containerd
sends SIGTERM to every container (Postgres, Frigate, etc. shut down cleanly),
the heph spokes and runner stop, and the zram swap is discarded (it is
RAM-backed; nothing to persist).

Shutdown takes about a minute. The last two clean shutdowns (April and May
2026) were each down ~5 minutes wall-clock including the boot.

### 3. Hardware work (if any)

Unplug the PSU mains cable and wait for the motherboard's standby LED to go
out before touching anything. Ground yourself. See the RAM-swap checklist
below for the memory case specifically.

## Startup procedure

### 1. Boot

Power on. The systemd-boot menu shows the NixOS generations and a
**Memtest86+** entry (see below). The default boots after a short timeout.

There is no TPM and no disk encryption prompt; boot is unattended. The wired
address is static, so ringtail is on the LAN and the tailnet within about a
minute of POST.

### 2. Log in at the console

Log in through greetd — Sway starts. This matters even if you are working
remotely because two things live in the **user** systemd manager and need
the eblume session:

- `eblume-heph-spoke` (Erich's heph sync)
- `myeve-heph-sync.timer`

Linger is enabled, so they start without a graphical login too, but the
1Password desktop app (needed for `op` on this host) does not. Start it from
the launcher if you will need `op`.

### 3. Verify

k3s comes up on its own and ArgoCD reconciles the auto-sync apps. Give it a
few minutes, then:

```fish
ssh ringtail 'systemctl --failed'                                     # expect: 0 loaded units
ssh ringtail 'sudo k3s kubectl get pods -A | grep -v -E "Running|Completed"'
mise run agent-health                                                 # Grafana alert state
mise run services-check                                               # fuller check (gilbert)
```

Things that commonly need a nudge:

- **Pods stuck `ContainerCreating` on the GPU node** — the NVIDIA device
  plugin registers after the driver loads; wait, then check
  `nvidia-device-plugin`.
- **Frigate or Immich `CrashLoopBackOff`** — usually waiting on its CNPG
  cluster to finish recovery; watch `kubectl get cluster -A`.
- **ArgoCD `Unknown` health on everything** — ArgoCD itself is still starting.
  Not an error.
- **Manual apps** (`apps`, `argocd`, `cloudnative-pg-ringtail`,
  `external-secrets-crds-ringtail`, `horkos`) do not sync on boot — they were
  not meant to, and a reboot does not need them to. Only sync if their
  manifests changed while ringtail was down.

## RAM-swap checklist

Written for the 2026-09 upgrade from 4x8 GB Corsair CMK16GX4M2B3200C16
(XMP/DOCP 3200 CL16 1.35 V) to 2x32 GB Crucial CT2K32G4DFD832A (JEDEC 3200
CL22 1.2 V, dual-rank). Adjust for whatever the next kit is.

**Before shutdown**

1. Make sure the Memtest86+ boot entry is present (`ls /boot/EFI` or check
   the boot menu on the next reboot). It is declared in
   `nixos/ringtail/configuration.nix`; if it is missing, `mise run
   provision-ringtail` first — you cannot add a boot entry once the box is
   down.
2. Record the current state for comparison:
   ```fish
   ssh ringtail 'sudo "$(nix build --no-link --print-out-paths nixpkgs#dmidecode)/bin/dmidecode" -t 17 | grep -E "Locator|Size|Part Number|Configured Memory Speed"'
   ```
   (`dmidecode` is not installed system-wide; the nix-build path is the
   least-effort way to run it as root.)

**Physical**

3. Two sticks go in **DIMM_A2 and DIMM_B2** — the grey pair, second and
   fourth slots counting from the CPU. That is ASUS's dual-channel
   recommendation for this board and the slot names match what the BIOS
   reports in DMI. Clips fully latched; the stick seats with a firm click on
   both ends.
4. Old sticks: bag them with the part number. DDR4 resale is worth it.

**First boot**

5. Enter the BIOS (Del at POST). Under Ai Tweaker, set **D.O.C.P. to
   Disabled** (or Auto). The Crucial kit has no XMP profile; its JEDEC table
   is already 3200 CL22 1.2 V. Leaving a stale DOCP profile selected is the
   most likely cause of a failed POST. The Crosshair VI Hero has a **MemOK!**
   button and a Q-code display if it will not train at all.
6. Save, reboot, pick **Memtest86+** in the boot menu, and let it run
   overnight (at least 4 full passes). Zero errors or the kit goes back —
   do this inside the retailer's return window.
7. Boot NixOS. Verify capacity, slots and trained speed:
   ```fish
   free -g
   ssh ringtail 'sudo "$(nix build --no-link --print-out-paths nixpkgs#dmidecode)/bin/dmidecode" -t 17 | grep -E "Locator|Size|Part Number|Configured Memory Speed"'
   ```
   Expect 32 GB in `DIMM_A2` and `DIMM_B2`, `No Module Installed` in A1/B1,
   part number `CT32G4DFD832A`. Any configured speed of 2666, 2933 or 3200 is
   fine: the Ryzen 7 1700X memory controller is officially rated 2400 for
   two dual-rank DIMMs, so whatever it trains to is a bonus. Capacity is the
   goal.
8. Update the RAM row and the "RAM speed" maintenance note in [[ringtail]].
9. Run the startup verification above. Then watch swap over the following
   days — the whole point was to stop living in zram (12.7 GB in use the day
   before the swap):
   ```fish
   mise run agent-metrics 'node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes'
   ```

## Related

- [[ringtail]] - Host reference and hardware table
- [[restart-indri]] - The indri equivalent
- [[manage-lockfile]] - Kernel updates that need a reboot
- [[troubleshooting]] - Diagnose issues after the restart
- [[power]] - UPS chain ringtail sits on
- [[disaster-recovery]] - Where this fits in the recovery index
