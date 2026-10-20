---
title: Per-Principal SSH
modified: 2026-10-20
last-reviewed: 2026-10-20
tags:
  - explanation
  - security
  - networking
---

# Per-Principal SSH

SSH into the homelab hosts authenticates **the principal**, not the device.
Tailscale SSH — which authenticates only the source node — is off on indri and
ringtail, and the tailnet ACL grants no Tailscale SSH to `tag:homelab`
(eblume/blumeops#1484). Every session into a homelab host is an OpenSSH session
authenticated by a key that belongs to exactly one principal.

## Why

The old ACL carried `tag:homelab → tag:homelab` Tailscale SSH `accept`: any
local user on one host — including the unprivileged `indri-build` CI user —
got a shell as any non-root user on the other, and both target users have
passwordless sudo. The rule existed because automation had no credentials of
its own and borrowed the host's tailnet identity; #1484 gave it its own.

## The mechanism

- **Humans** use their 1Password "SSH - Personal" key via the 1Password agent,
  against each host's OpenSSH `sshd`, key-only: ringtail's stock sshd (one
  authorized key for `eblume`) and indri's nix-darwin-managed sshd
  (`AllowUsers erichblume`, [[indri]] §Nix). The tailnet's L4 grants
  (homelab↔homelab, all ports) are the transport — unchanged by #1484; only
  Tailscale's in-band SSH is gone.
- **Automation** gets its own on-disk key (a copy held in 1Password), one per
  principal: indri's borgmatic role carries
  `~/.ssh/borgmatic_ringtail_ed25519` (`IdentitiesOnly`), authorized on
  ringtail for the dedicated `borgmatic` user with `restrict` and a forced
  command pinned to the `borgmatic-dump` endpoint — only dump names cross the
  wire ([[ringtail]] §Borgmatic dump endpoint, [[borgmatic]]).

## Guardrails

`policy.hujson`'s `sshTests` pin the denials server-side: `tag:talos` gets no
Tailscale SSH anywhere, and `tag:homelab → tag:homelab` is denied — so
re-granting a device-level rule fails `mise run tailnet-up` instead of landing
silently. (eblume/blumeops#441, which closed unmerged over exactly this rule,
is the origin of that pin.) Post-cutover check:
`sudo -u indri-build ssh eblume@ringtail true` must fail.

## Related

- [[tailscale]] — ACL reference and the current SSH table
- [[ringtail]] — the `borgmatic` dump endpoint
- [[indri]] — the OpenSSH sshd configuration
- [[agent-containerization]] — the `tag:talos` device-identity fence this complements
