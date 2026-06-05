---
title: Hephaestus
modified: 2026-06-04
last-reviewed: 2026-06-04
tags:
  - service
  - hephaestus
---

# Hephaestus

[hephaestus](https://github.com/eblume/hephaestus) (`heph`) is the user's
self-hosted task + context/knowledge system. It is **hub-and-spoke**: each device
runs a full local SQLite replica (`hephd --mode local`) and background-syncs
against one canonical **hub**. Indri runs that hub.

## Quick Reference

| Property | Value |
|----------|-------|
| **PWA URL** | https://heph.ops.eblu.me (browser PWA, Caddy TLS) |
| **Spoke sync URL** | http://indri.tail8d86e.ts.net:8787 (direct, tailnet) |
| **Local Port** | 8787 (`hephd --mode server`, bound `0.0.0.0`) |
| **Binary** | `~/.cargo/bin/hephd` (self-updating) |
| **Data** | `~/.local/share/heph/heph.db` |
| **PWA shell** | `~/.local/share/heph/web` |
| **Logs** | `~/Library/Logs/mcquack.heph.{out,err}.log` |
| **LaunchAgent** | `mcquack.eblume.heph` |
| **Ansible role** | `ansible/roles/heph` (tag `heph`) |

## What runs on indri

The launchagent runs the hub in server mode with three features enabled:

```
hephd --mode server --http-addr 0.0.0.0:8787 --db ~/.local/share/heph/heph.db
      --web-root ~/.local/share/heph/web
      --oidc-issuer https://authentik.ops.eblu.me/application/o/heph/
      --oidc-audience heph
      --self-update --self-update-interval-secs 600
```

- **Server mode** exposes the HTTP sync endpoint (`/rpc`, `/sync/*`) that spokes
  reconcile their op-log against.
- **Self-update** (10-minute poll) rebuilds `hephd` from the forge when a newer
  release tag appears (`cargo install --git https://forge.eblu.me/eblume/hephaestus.git`).
  Indri's Rust toolchain (`~/.cargo/bin`) is on the agent's `PATH` for this, and
  the plist pins `RUSTUP_TOOLCHAIN=stable` — the
  launchagent runs without mise, so a bare `cargo` shim would otherwise fall back
  to rustup's *default* toolchain, which can lag behind heph's `rust-version` floor
  (1.89) and silently fail the build.
- **PWA** (`--web-root`) serves the [heph-pwa] mobile shell; Caddy terminates TLS
  at `heph.ops.eblu.me` so the PWA runs in a secure context (service worker,
  install-to-home-screen, voice capture).

[heph-pwa]: https://github.com/eblume/hephaestus

The hub binds `0.0.0.0` so tailnet spokes can also sync directly
(`http://indri.tail8d86e.ts.net:8787`); access is gated by Authentik OIDC either
way — tailnet reachability alone is not enough.

## Authentication (Authentik OIDC, device-code)

The hub verifies an OIDC bearer token on every sync. The `heph` application is a
**public** OAuth2 client using the **device-code flow** (RFC 8628), provisioned
in the [[authentik]] blueprint (`argocd/manifests/authentik/configmap-blueprint.yaml`):

- Issuer: `https://authentik.ops.eblu.me/application/o/heph/`
- Audience / client id: `heph`
- Restricted to the `admins` group (single-owner, sensitive data).

Because no Authentik instance ships a device-code flow by default, the blueprint
also creates `default-device-code-flow` and binds it to the default brand's
`flow_device_code`. Devices obtain a token with `heph auth login`; the PWA
currently takes a pasted token (in-app device-code login is upstream follow-up).

## Data seeding (Path A, one-time)

The hub was seeded from the existing `gilbert` device so no task history was
lost. heph's data-safe bring-up ("Path A") has the hub **adopt the device's
identity** rather than rewriting the device:

1. Quiesce the seed device: `heph daemon stop` (on gilbert).
2. Copy its store to indri: `scp ~/.local/share/heph/heph.db indri:~/.local/share/heph/heph.db`.
3. Give the hub its **own device origin** (keeps gilbert's `owner_id` + data;
   `hephd` regenerates a fresh `origin` on next start when it is missing):
   ```fish
   ssh indri "sqlite3 ~/.local/share/heph/heph.db \"DELETE FROM meta WHERE key='origin';\""
   ```
4. `mise run provision-indri -- --tags heph` (installs hephd, stages the PWA,
   loads the launchagent → hub starts on the seeded store).

Only `meta.origin` changes; `owner_id`, nodes, op-log, and links are copied
untouched. A clean `hephd --owner-id` / seed command is tracked upstream as
hephaestus follow-up — until then this manual reset is the documented path.

## Connecting a spoke (e.g. gilbert)

A device joins by running its local daemon with the hub URL + OIDC client and
logging in once:

```bash
hephd --mode local --hub-url http://indri.tail8d86e.ts.net:8787 \
      --oidc-issuer https://authentik.ops.eblu.me/application/o/heph/ \
      --oidc-client-id heph
heph auth login --hub-url http://indri.tail8d86e.ts.net:8787 \
      --issuer https://authentik.ops.eblu.me/application/o/heph/ --client-id heph
```

> **Use the direct `http://…:8787` tailnet URL for sync, not the Caddy HTTPS
> URL.** hephd's sync client is plain-HTTP-only; pointing `--hub-url` at
> `https://heph.ops.eblu.me` fails with a confusing `error sending request`
> (the HTTP connector rejects the `https` scheme before connecting). Tailscale
> encrypts the transport, and the OIDC bearer token still gates every request.
> `heph.ops.eblu.me` (Caddy TLS) exists only for the browser PWA, which needs a
> secure context. The cached token is keyed by the exact `--hub-url`, so use the
> same value for `hephd` and `heph auth login`.

> **Caveat:** `heph daemon` cannot yet bake hub/spoke flags into the generated
> launchd plist (upstream gap). On a spoke whose plist is managed by `heph
> daemon`, the hub/OIDC flags must be hand-added — and a later `heph daemon
> start/restart` will regenerate the plist and drop them. Avoid `heph daemon`
> subcommands on a configured spoke until that gap is closed; reload via
> `launchctl` instead.

## Related

- [[indri]] — host
- [[authentik]] — OIDC provider
- [[caddy]] — TLS termination for `heph.ops.eblu.me`
