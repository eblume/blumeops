---
title: Hephaestus
modified: 2026-09-12
last-reviewed: 2026-09-12
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
| **Binary** | indri hub: `~/.cargo/bin/hephd` (the ringtail spokes run the nix-store package — see [Version management](#version-management)) |
| **Data** | `~/.local/share/heph/heph.db` |
| **PWA shell** | `~/.local/share/heph/web` |
| **Logs** | `~/Library/Logs/mcquack.heph.{out,err}.log` |
| **LaunchAgent** | `mcquack.eblume.heph` |
| **Ansible role** | `ansible/roles/heph` (tag `heph`) |

## What runs on indri

The launchagent runs the hub in server mode:

```
hephd --mode server --http-addr 0.0.0.0:8787 --db ~/.local/share/heph/heph.db
      --web-root ~/.local/share/heph/web
      --oidc-issuer https://authentik.ops.eblu.me/application/o/heph/
      --oidc-audience heph
```

- **Server mode** exposes the HTTP sync endpoint (`/rpc`, `/sync/*`) that spokes
  reconcile their op-log against.
- **PWA** (`--web-root`) serves the [heph-pwa] mobile shell; Caddy terminates TLS
  at `heph.ops.eblu.me` so the PWA runs in a secure context (service worker,
  install-to-home-screen, voice capture). On every provision the role also
  stamps the `heph_version` tag as `pwa-version.js` in the web root, which the
  PWA settings menu displays as its active version.

> **No `--self-update`.** hephd's opt-in self-updater is deliberately **off**
> everywhere (hub and spokes). Versions are pinned in IaC and converged by the
> provisioner — see [Version management](#version-management). Leaving it off
> means a fresh upstream release never lands on a device until a human bumps the
> pin and re-provisions, so a release can't silently roll out (or roll out a
> regression) between reviews.

[heph-pwa]: https://github.com/eblume/hephaestus

The hub binds `0.0.0.0` so tailnet spokes can also sync directly
(`http://indri.tail8d86e.ts.net:8787`); access is gated by Authentik OIDC either
way — tailnet reachability alone is not enough.

## Version management

Every heph binary in the network is pinned to an explicit release tag in IaC;
**nothing auto-updates**. Upgrading is a deliberate, reviewed step: cut the
upstream release, then bump the pin and re-provision.

| Device | Managed by | Pin | Converged by |
|--------|-----------|-----|--------------|
| **indri** (hub) | `ansible/roles/heph` | `heph_version` (`defaults/main.yml`) | `mise run provision-indri -- --tags heph` — installs/upgrades `hephd` to the pinned tag on every run |
| **ringtail-agent** (spoke) | `nixos/ringtail/flake.nix` (`hephaestus` input) | flake input ref (tag + tag-commit rev) | the toplevel build — the spoke starts at boot, no install oneshot |
| **ringtail-eblume** (desktop spoke) | `nixos/ringtail/flake.nix` (`hephaestus` input) | flake input ref (tag + tag-commit rev) | the toplevel build — the user service starts at boot via linger, no install oneshot |
| **gilbert** (spoke) | manual (not yet IaC) | — | hand `cargo install --tag`; see [Connecting a spoke](#connecting-a-spoke-eg-gilbert) |

Both ringtail spokes share one pin: the `hephaestus` flake input in
`nixos/ringtail/flake.nix` — bump it and review both spokes. A pin bump
rewrites both spokes' unit files and the nixos switch restarts them on file
change: the agent's system unit, and eblume's user unit — since nixos-25.11
the switch (switch-to-configuration-ng) restarts changed user units for every
user whose manager is running, and lingering keeps user@1000 up.

Because both spokes' hephd is a toplevel store path, no heph build ever runs
on the activation path (eblume/blumeops#1003's mid-activation compile is
closed). The standing trade of pinning the flake input's nixpkgs to the
channel: the package builds with the pinned nixos-26.05 rustc, so a heph
floor bump that outruns that rust is resolved by adding a pinned rust
overlay to the ringtail flake — one flake.lock change, and still no second
toolchain path on the host.

The indri role converges the version on **every** provision (it compares
`hephd --version` against `heph_version` and re-runs `cargo install --locked
--tag …` on a mismatch), so bumping the pin and re-provisioning is all an
upgrade takes — and it will also **downgrade** if the pin is lowered. That
`cargo install` build runs with `RUSTUP_TOOLCHAIN` (`heph_rust_toolchain`,
`stable`): ansible runs without mise, so a bare `cargo` shim would otherwise
fall back to rustup's *default* toolchain, which can lag behind heph's
`rust-version` floor and silently fail the build.

**Release → deploy flow:**

1. Cut the upstream release (new `vX.Y.Z` tag on the hephaestus repo).
2. Bump the pins in blumeops: `heph_version` (ansible, hub) and the
   `hephaestus` flake input (both ringtail spokes, nixos/ringtail/flake.nix).
   Open a PR as usual.
3. After review, converge each device:
   - indri: `mise run provision-indri -- --tags heph`
   - ringtail: nixos rebuild — both spokes' hephd is built into the toplevel
     by the flake input (the ringtail-flake-check runner builds it on
     ringtail's own nix store, so the switch reuses it); the switch restarts
     both spokes on unit-file change
   - gilbert: run the `cargo install --tag vX.Y.Z` step below.
4. Confirm: both spokes are in the toplevel, so after the switch
   `systemctl is-active agent-heph-spoke` and
   `sudo systemctl --machine=eblume@.host --user is-active eblume-heph-spoke`
   (on ringtail) are their check — each version is the flake input's pin by
   construction.

## Backups

The hub DB (`~/.local/share/heph/heph.db`) is the **only** copy of all
task/context data once spokes are pure replicas, so it is backed up daily by
[[borgmatic]] on indri. Because the hub writes continuously (every spoke sync)
in WAL mode, a plain file copy could tear — so a before-backup hook
(`borgmatic_archive_sqlite_dumps` in the borgmatic role) stages a WAL-safe online
`sqlite3 .backup` snapshot into the archive. (We avoid borgmatic's native
`sqlite_databases` hook because its `sqlite3 .dump` can fail *silently* on a WAL
DB; `.backup` returns a real exit code, so a bad snapshot aborts the run.) See
[[backups]].

## Authentication (Authentik OIDC, device-code)

The hub verifies an OIDC bearer token on every sync. The `heph` application is a
**public** OAuth2 client using the **device-code flow** (RFC 8628), provisioned
in the [[authentik]] blueprint (`argocd/manifests/authentik/configmap-blueprint.yaml`):

- Issuer: `https://authentik.ops.eblu.me/application/o/heph/`
- Audience / client id: `heph`
- Restricted to the `admins` group (single-owner, sensitive data).
- Scope mappings: `openid`, `email`, `profile`, **`offline_access`**.

> **`offline_access` is required for durable sync.** The `heph` CLI requests
> `scope = "openid offline_access"`, and a refresh token is only issued for the
> 30-day refresh-token window when the provider actually grants `offline_access`.
> Without that scope mapping the refresh token is bound to the login **session**;
> once the session lapses, hephd's `refresh_token` grant returns `400 Bad
> Request`, the bearer can't be refreshed, and spoke sync silently degrades
> (`heph sync --status` → `auth_failure: true`). `heph auth login` papers over it
> until the next session expiry. Keep `offline_access` in the provider's
> `property_mappings`.

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

## Desktop surfaces on ringtail

Erich's ringtail spoke (`nixos/ringtail/heph-eblume.nix`) is a **desktop**
spoke: its `desktopBins` list adds `heph-tui` and `heph-quickadd` to the
`heph`/`hephd` the agent's headless spoke runs — all from the same nix-store
package.

> **The store package's bin dir is on no session `PATH` here.** sway comes up
> under greetd with only the nix profile directories, and neither fish's
> config nor `fish_user_paths` adds it — so a terminal opened from the desktop
> cannot see `heph` or `heph-tui` at all, however they are installed.
> `mkShims` puts exec shims in eblume's home-manager profile
> (`/etc/profiles/per-user/eblume/bin`, which *is* on that PATH) for exactly
> the `desktopBins` the spoke runs. Check with a genuinely clean environment,
> not an agent/harness shell — those often carry extra `PATH` entries and will
> hide the problem:
>
> ```fish
> env -i HOME=$HOME USER=eblume PATH=(tr '\0' '\n' < /proc/(pgrep -x sway)/environ | grep '^PATH=' | cut -d= -f2) fish -l -c 'type -P heph-tui'
> ```

**Quick capture is bound in sway, not in the app.** On gilbert the popover is an
always-warm process that grabs ⌘' for itself; that model cannot work under
Wayland, where a window cannot be hidden (winit's `set_visible` is a no-op, so a
"hidden" popover would sit on screen) and there is no global key grab at all. So
sway owns the binding — **Alt+'**, which also means it fires regardless of which
application has focus — and launches `heph-quickadd popover`, the upstream
one-shot mode: one process per capture, exiting when saved, escaped, or clicked
away. The binding and the float/centre window rule live in `configuration.nix`
next to the rest of the sway config; the launcher itself
(`heph.mkQuickaddLauncher`) is in `heph-common.nix`.

> **Why a launcher wrapper at all.** The store's `heph-quickadd` is already
> wrapped with its graphics stack (the hephaestus flake prefixes
> `LD_LIBRARY_PATH` with the eframe dlopen libs and `/run/opengl-driver/lib`
> for the GL ICDs), so the launcher is just the one-shot `popover` mode
> invocation sway's binding needs: one process per capture.

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

### Turning off self-update on a manual spoke (gilbert)

gilbert's spoke is not yet under IaC, so its version and self-update state are
managed by hand. To bring it in line with the network policy (no auto-update,
pinned version), run these **on gilbert** (adjust the plist label/path if it
differs):

```bash
# 1. Find the launchd label and plist for the spoke daemon.
launchctl list | grep -i heph
ls ~/Library/LaunchAgents | grep -i heph

# 2. Inspect the current ProgramArguments — look for --self-update.
plutil -p ~/Library/LaunchAgents/<label>.plist | grep -A40 ProgramArguments
```

If `--self-update` (and `--self-update-interval-secs`) appear, remove them. Note
`heph daemon` treats self-update as **sticky** (it re-adds the flag on every
`start`/`restart` once it has been enabled, and offers no flag to disable it), so
the plist must be edited directly and `heph daemon start/restart` avoided:

```bash
# 3. Stop the daemon, strip the self-update flags, and pin the binary.
heph daemon stop        # or: launchctl unload ~/Library/LaunchAgents/<label>.plist

# Edit ~/Library/LaunchAgents/<label>.plist by hand: delete the
#   <string>--self-update</string>
#   <string>--self-update-interval-secs</string><string>NNN</string>
# entries from <array> under ProgramArguments. Keep every other argument.

# 4. Pin hephd to the network's current tag (matches heph_version in ansible).
RUSTUP_TOOLCHAIN=stable ~/.cargo/bin/cargo install --locked \
  --git https://forge.eblu.me/eblume/hephaestus.git --tag v1.10.6 heph hephd

# 5. Reload via launchctl (NOT `heph daemon`, which would re-add self-update).
launchctl unload ~/Library/LaunchAgents/<label>.plist 2>/dev/null || true
launchctl load   ~/Library/LaunchAgents/<label>.plist

# 6. Verify: version matches the pin and no self-update flag remains.
~/.cargo/bin/hephd --version
plutil -p ~/Library/LaunchAgents/<label>.plist | grep -c self-update   # → 0
```

On each future release, redo step 4 with the new tag (there is no poller to do
it automatically — that is the point). Folding gilbert into IaC (an ansible
spoke role, mirroring the indri hub role) is tracked as follow-up.

## Related

- [[indri]] — host
- [[authentik]] — OIDC provider
- [[caddy]] — TLS termination for `heph.ops.eblu.me`
