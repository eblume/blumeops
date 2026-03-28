---
title: Troubleshoot Sifaka NFS
modified: 2026-03-28
last-reviewed: 2026-03-28
tags:
  - how-to
  - storage
  - nfs
---

# Troubleshoot Sifaka NFS

How to diagnose and fix NFS permission failures on [[sifaka]].

## Symptom

NFS mounts from ringtail (or any Tailscale client) to sifaka fail with "Permission denied". Frigate shows empty storage stats. The `frigate-storage` check in `mise run services-check` fails. Existing mounts go stale — even `ls` on the mount point returns EACCES.

## Root Cause: Tailscale Userspace Networking

Sifaka runs Tailscale via the Synology DSM package. On DSM 7, the package can run in two modes:

| Mode | `TUN` flag | NFS sees source IP as | NFS result |
|------|-----------|----------------------|------------|
| **TUN (kernel)** | `True` | Client's Tailscale IP (e.g. `100.121.200.77`) | Works — matches `100.64.0.0/10` export rule |
| **Userspace** | `False` | `127.0.0.1` (loopback) | Fails — doesn't match any export rule |

In userspace mode, Tailscale proxies connections through loopback. The NFS daemon sees `127.0.0.1` as the source IP, which doesn't match the `100.64.0.0/10` or `192.168.1.0/24` export rules, so it rejects the mount.

## Diagnosis

```bash
# Check Tailscale mode on sifaka
ssh sifaka '/var/packages/Tailscale/target/bin/tailscale status --json' | python3 -c "import sys,json; print('TUN:', json.load(sys.stdin).get('TUN'))"

# If TUN: False, that's the problem

# Confirm NFS lease failures on ringtail
ssh ringtail 'sudo dmesg | grep -i nfs | tail -5'
# Look for: "check lease failed on NFSv4 server sifaka with error 13"
```

## Fix

The DSM Task Scheduler has a boot-up task ("Enable tailscale outbound TUN") that runs:

```bash
/var/packages/Tailscale/target/bin/tailscale configure-host;
synosystemctl restart pkgctl-Tailscale.service
```

`configure-host` grants the Tailscale package permission to open `/dev/net/tun` (which is `crw-------` root-only by default on DSM 7). The service restart then picks up TUN mode.

**To fix immediately:** In DSM, go to Control Panel > Task Scheduler, select "Enable tailscale outbound TUN", and click Run.

**Note:** Running this task restarts Tailscale, which briefly drops all Tailscale connections to sifaka. SSH sessions over Tailscale will disconnect but reconnect within seconds.

After Tailscale restarts, restart the affected pods to get fresh NFS mounts:

```bash
kubectl --context=k3s-ringtail rollout restart deployment/frigate -n frigate
```

## Why It Recurs

The "Update Tailscale" scheduled task runs nightly (`tailscale update --yes`). Package updates can reset the TUN device permissions, reverting to userspace mode. The boot-up task only runs at boot, not after updates.

If this keeps recurring, consider adding `tailscale configure-host` to the update task as well, or running it on a schedule.

## Related

- [[sifaka]] — NAS reference card
- [[frigate]] — Primary NFS consumer affected by this issue
