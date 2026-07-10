---
title: Host Factorio for a Guest
modified: 2026-07-10
last-reviewed: 2026-07-10
tags:
  - how-to
  - ringtail
  - tailscale
---

# Host Factorio for a Guest

How to run the private Factorio server on [[ringtail]] and give an outside
friend access to it — and *only* it — without making them a member of the
tailnet. This is BlumeOps' first externally-shared service, so the pattern here
is the template for future "just one service" guests.

The design decision that makes this safe: **share the machine, do NOT invite the
guest as a user.** See [[tailscale]] for the ACL model.

## What's in git

Three source changes bring the service and its access path up (deploy in any
order; the server should be running before a guest connects):

| Change | File | Effect |
|--------|------|--------|
| NixOS service | `nixos/ringtail/factorio.nix` (+ import in `configuration.nix`) | Runs `services.factorio` on UDP 34197. `openFirewall = false` — the port is reachable via the already-trusted `tailscale0` interface, not the LAN/WAN. |
| DNS name | `pulumi/gandi/__main__.py` | Exact **CNAME** `factorio.ops.eblu.me → ringtail.tail8d86e.ts.net` (overrides the `*.ops → indri` wildcard; the game is UDP and bypasses Caddy). A CNAME, **not** an A record — see "Why a CNAME, not an A record" below. |
| ACL grant | `pulumi/tailscale/policy.hujson` | `tag:factorio` tag owner + a grant giving `autogroup:shared` exactly `udp:34197` on `tag:factorio`. |
| ringtail tag | `pulumi/tailscale/__main__.py` | Adds `tag:factorio` to ringtail's declaratively-managed device tags. **Do this in Pulumi, not the admin console** — `ringtail_tags` is a `DeviceTags` resource that replaces the device's tags, so a console-added tag would be stripped on the next `tailnet-up`. |

Deploy: `provision-ringtail` for the service, `pulumi up` in `pulumi/gandi` and
`pulumi/tailscale` for DNS and ACL.

## Why sharing ≠ opening every port

Sharing ringtail makes the **device** visible/routable to the guest — nothing
more. What they can actually *reach* is still governed by ACL grants, which are
default-deny. Our grant hands `autogroup:shared` only `udp:34197`, so every
other port on ringtail (k3s `6443`, SSH `22`, kubelet, agent workspaces, …) has
no matching grant and stays blocked. This is enforced by tailscaled's per-node
packet filter on ringtail itself — important here because ringtail's host
firewall trusts all of `tailscale0`, so the ACL, not the host firewall, is the
wall.

Two independent layers protect you:

1. **Visibility (sharing):** the guest sees *only* ringtail. indri, sifaka, the
   NAS, the k8s services — none are shared, so they don't exist from their side.
2. **Reachability (the ACL grant):** on the one machine they can see, they get
   one UDP port.

## Manual steps (not in git — a human does these once)

ringtail's `tag:factorio` is applied by Pulumi (see the table above), **not** the
console. The only genuinely-manual step is the share itself, done in the
Tailscale admin console:

1. **Share ringtail with the guest** — admin console → **Machines → ringtail →
   `⋯` menu → Share…**. Enter their email or generate a share link. **Do NOT use
   the "Invite users" flow** — that would make them a `member` and they'd inherit
   Forgejo/Kiwix/Miniflux. Sharing makes them `autogroup:shared` instead, which
   is separate and non-overlapping with `autogroup:member`.
2. **Guest accepts** the share while signed into their own Tailscale. ringtail
   appears in their machine list flagged *shared*; they see nothing else.

### Optional: tighten the grant to a named guest

The shipped grant uses `autogroup:shared` (any shared user). That's safe — it
only ever matches shared users and only on the machine carrying `tag:factorio`.
To scope it to one person, replace `autogroup:shared` in `policy.hujson` with
their exact Tailscale login identity (visible on ringtail's "Shared with" list
after they accept), and add a positive ACL test naming them.

## The guest connects

Factorio → **Multiplayer → Connect to address** → `factorio.ops.eblu.me` (or
`factorio.ops.eblu.me:34197`). Their Tailscale must be up; the CNAME resolves,
via *their* MagicDNS, to ringtail at whatever address it carries in their
tailnet, which their Tailscale routes to the shared machine.

If `factorio.ops.eblu.me` times out for a guest (a strict split-DNS client — see
below), have them connect to **`ringtail.tail8d86e.ts.net:34197`** directly. That
MagicDNS name always resolves correctly for any tailnet participant.

> **Note:** the guest cannot `ping` the server, and that's expected — the ACL
> grants only `udp:34197`, not ICMP. A failed ping does **not** mean a failed
> connection; only the game port is open.

## Why a CNAME, not an A record

The obvious design — a public A record `factorio.ops.eblu.me → <ringtail's 100.x>`
— **does not work for shared guests**, and this bit us on the first real guest.

Tailscale IPs are not globally unique across tailnets. When ringtail is *shared*
into a guest's tailnet and its owner-tailnet IP collides with a device the guest
already has, Tailscale **remaps** ringtail to a different `100.x` address in the
guest's tailnet. In the first case ringtail was `100.121.200.77` here but showed
up as `100.121.200.76` in the guest's tailnet; `.77` didn't exist on their side
at all. A pinned A record publishes *our* `.77`, which the guest can't route —
so the name times out for them even though the share and ACL are correct.

A CNAME to the MagicDNS name fixes this by never hardcoding an address: each
client's own Tailscale resolves `ringtail.tail8d86e.ts.net` to the IP correct for
*its* view. Owner resolves `.77`, guest resolves `.76`, both reach ringtail.

The one limitation: MagicDNS names aren't in public DNS, so the CNAME only
resolves for clients that send lookups through the Tailscale resolver. A client
on strict split-DNS (only `*.ts.net` routed to Tailscale, everything else to a
public resolver) will fail the CNAME's second lookup — those guests use the
`ringtail.tail8d86e.ts.net` name directly, as noted above.

## Revoking access

Either mechanism cuts them off; doing both is clean:

- **Un-share** ringtail (removes visibility), and/or
- delete the `autogroup:shared → tag:factorio` grant (removes reachability).

## Future hardening

If you ever want the guest to not even *see* ringtail, run Factorio in a
container with its own userspace/TUN `tailscaled` tagged **only** `tag:factorio`,
and share *that* node — then the shared device carries no sensitive tags. Not
worth it for a two-player game; noted for when a third guest shows up. Migrating
is just moving `tag:factorio` onto the new node — the ACL grant is already
written generically against the tag.

## Related

- [[ringtail]] — host reference
- [[tailscale]] — ACL / sharing model
- [[routing]] — DNS and reverse-proxy layout
