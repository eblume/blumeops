---
title: Provision Indri
modified: 2026-09-17
last-reviewed: 2026-09-16
tags:
  - how-to
  - indri
  - nix
---

# Provision Indri

[[indri]] runs a nix-darwin system profile (the `darwin/indri/` flake) plus
the ansible roles it has not absorbed yet (secret placement, source builds,
most services). `mise run provision-indri` is the single apply path, shaped
like ringtail's: two guards, then the play.

## What the task does

1. `nix flake lock` in a nixos/nix container — `nix flake lock` only
   resolves inputs, so it works from any controller. If
   `darwin/indri/flake.lock` changes, the task stages it and exits: commit,
   push, re-run.
2. Fail if HEAD is not pushed to origin.
3. `ansible-playbook playbooks/indri.yml -e "indri_commit=<sha>"`:
   controller-side `op` reads, then the `rebuild` tasks (below), then the
   service roles. The rebuild tasks sit at the end of `pre_tasks` — ansible
   runs `tasks:` *after* `roles:`, so that is the only place "before the
   roles" is true.


## The rebuild tag (zero-prompt apply)

The checkout and rebuild tasks are tagged `rebuild`, so
`mise run provision-indri -- --tags rebuild` applies a new generation with no
1Password prompts (a full run costs ~20, one per `op read`). The tasks
checkout the bound SHA into a root-owned `/etc/blumeops` (HTTPS from the
forge, forced) and run `darwin-rebuild switch --flake
/etc/blumeops/darwin/indri#indri` detached via `sudo -H nohup` — log at
`/var/log/indri-rebuild/<sha>.log` plus a `.status` sidecar — then wait
(bounded, 60 min) and fail with the log embedded on non-zero exit. `-H`
matters: macOS `sudo` keeps `$HOME`, and root's `nix build` would otherwise
leave root-owned files in `~erichblume/.cache/nix` that break the
user-run flake check and the CI job on the indri runner.

The rebuild path also converges `/etc/resolver/ts.net` before the switch:
its resolver-write pre_task is tagged `[rebuild, tailnet-dns]` and writes
it as a real file — a store symlink would dangle in the pre-Nix-
Store-mount window and mDNSResponder would never rescan it (see the
Reboot test below).

The play resolves `darwin-rebuild` from `/run/current-system`, falling back
to the system profile (`/nix/var/nix/profiles/system/sw/bin`). Before the
first switch there is no `/run/current-system` at all (it appears only after
an activation has run); after that it survives reboots (the first reboot
test initially found BTM disallowing the daemon; see below).

If a run dies mid-rebuild (session drop, pod replacement, the wait
timing out), the switch keeps running detached and will have left
`/var/log/indri-rebuild/<sha>.status` (the exit code) and `.log`. The play
only rebuilds when the checkout changes, so re-running the same commit
reports clean and does not retry: read the status file before re-applying,
and fix forward with a new commit if the switch failed.

## Toolchain

The generation owns the global mise config (`environment.etc."mise/config.toml"`
in `darwin/indri/configuration.nix`, symlinked into the user home by the
postActivation fragment — see [[indri]] §Toolchain). A toolchain-only PR (a
pin bump) therefore applies with the usual `mise run provision-indri -- --tags
rebuild`: no service-role tag, and no plist flips. Rollback is a plain
`darwin-rebuild --rollback` — the fragment re-links the previous generation's
config, and tool installs are additive, so rolling back never removes a tool.
See [[provision]] §Rolling back a service flip for what `--rollback` does and
does not do.

## Metrics agents

The four `*-metrics` collectors (borgmatic, forgejo, jellyfin, zot) are
nix-managed user agents (PR 4 of the series) at the same labels and plist
paths the ansible roles used, writing the same `.prom` files into alloy's
node_exporter textfile dir and the same `/opt/homebrew/var/log` logs.
Applying the flip is the usual `mise run provision-indri -- --tags rebuild`
(no service-role tag): activation swaps each plist in place — one reload,
never dual-loaded. The API key files (`~/.forgejo-api-key`,
`~/.jellyfin-api-key`) stay controller-side `op` placement: the roles'
key-file tasks are not gated. Rollback per §Rolling back a service flip,
with all four roles' gates flipped.

An unload leaves the `.prom` files in place and node_exporter keeps
serving them, so Prometheus never sees a gap: for these textfile
collectors the outage signal is `node_textfile_mtime_seconds` aging
(and the TextfileStale alert once it crosses threshold), not a scrape
gap — a window's "no gaps in the tails" verification therefore means
no gap *and* mtime fresh.

## Zot registry

The zot registry is the first real daemon the series moves (PR 5): a
long-running process, not a collector. The unit is a nix-managed user
agent (`mcquack.eblume.zot`) at the same label and plist path the
ansible role used; the source-built binary stays at `~/code/3rd/zot`
(out of nix's scope) and the `config.json` / `oidc-credentials.json`
files stay role-rendered — the role's gate (`zot_ansible_managed`)
covers only the plist + load tasks. Applying the flip is the usual
`mise run provision-indri -- --tags rebuild` (no service-role tag):
activation writes the plist in place and reloads the agent once. What
changes the drill: with the unit unloaded, zot is down — the registry
and every image pull/push behind it — until something reloads the
unit, so the rollback drill below is planned around a real outage.
Rollback per §Rolling back a service flip, with the role's gate
flipped.

## Caddy

Caddy is the widest daemon the series moves (PR 6): it fronts every
`*.ops.eblu.me` endpoint and the L4 routes (forge ssh 2222, postgres
5433/5434, the sifaka exporter ports). The unit is a nix-managed user agent
(`mcquack.eblume.caddy`) at the same label and plist path the ansible
role used; the xcaddy-built binary stays at `~/code/3rd/caddy` (out of
nix's scope) and the `Caddyfile`, wrapper script and Gandi token file
stay role-rendered — the role's gate (`caddy_ansible_managed`) covers
only the plist + load tasks. Applying the flip is the usual
`mise run provision-indri -- --tags rebuild` (no service-role tag):
activation writes the plist in place and reloads the agent once.

The drill's blast radius is everything caddy fronts: with the unit
unloaded, the forge API and ssh, the registry, and every image pull
from the cluster are down, and indri's own runner cannot reach
`forge.ops.eblu.me` — so no CI runs land during the drill either.
Ansible itself is unaffected (it reaches indri over tailscale ssh, not
through caddy) and `op` is unaffected. After the forward switch,
verify every endpoint and the L4 routes, per the plan.

Rollback per §Rolling back a service flip, with the role's gate
flipped.

## Pre-apply check: indri-flake-check

`mise run indri-flake-check` builds `.#darwinConfigurations.indri.system` on
indri itself, at the local HEAD — the exact commit `provision-indri` would
deploy. It must run on the box: no off-box host can evaluate aarch64-darwin.
Run it from any blumeops checkout before a window.

## CI coupling

The Indri Flake Check workflow (`.forgejo/workflows/indri-flake-check.yaml`)
runs the same build on the indri runner when a PR or a push to main
touches `darwin/indri/` (or the workflow file itself), against indri's own
store — the check lives where the target platform is, because ringtail
cannot evaluate aarch64-darwin. The runner's PATH carries
`/nix/var/nix/profiles/default/bin` for this (forgejo-runner.plist.j2);
erichblume is not a trusted nix user, which is fine for a flake build.

## There is no dry run of a switch

nix-darwin's `activate` script starts with `#!/usr/bin/env -i bash`, which
discards the environment — including the `checkActivation=1` that
`darwin-rebuild check` sets — so **any invocation of `activate` is a full
activation as root**. (On 2026-09-16 a "no-write rehearsal" built on that
flag activated the first generation outside the play; no damage, but see
[[indri]] §Nix for the host-key consequence.) Rehearse with
`indri-flake-check` (eval + build) and by reading the abort conditions in
the built `activate` script; treat everything else as the real switch.

## First switch (one-way)

The first generation changes only the target of `/etc/static` (equivalent
content, re-owned from the dormant 25.05 generation) and declares no
services or agents. The switch is one-way by necessity: the old generation
(system-14) must never be re-activated — its etc check carries the
pre-Tahoe zsh hash list and aborts on the post-Tahoe `/etc/zshrc`, and it
declares `services.tailscale`, which would load a second tailscaled beside
the Homebrew root daemon.

Step 0, before the window (human, **at indri's console — a Terminal on
the box, not over ssh**): the Determinate upgrade —
`sudo installer -pkg Determinate.pkg -target /` from
`https://install.determinate.systems/determinate-pkg/stable/Universal` —
with a `tar -h` of `/etc/static` as insurance, then re-verify
`nix store info`, a trivial `nix build`, and
`launchctl list | grep mcquack` unchanged.

Why the console: macOS Tahoe TCC-protects `/etc/fstab`, and the
responsible process for a Tailscale SSH session is Homebrew `tailscaled`,
which has no Full Disk Access — so over ssh the installer's
`create_fstab_entry` step dies with `Operation not permitted` (root is
irrelevant to TCC), after its uninstall phase 1 has already removed the
`systems.determinate.nix-store` boot-mount plist. If that happens: do not
reboot; park the partial receipt (`sudo mv /nix/receipt.json
/nix/.partial-receipt.json`) and run the same install line from
Terminal.app on indri — `sudo /nix/nix-installer install macos
--no-confirm --encrypt true --ssl-cert-file /etc/nix/macos-keychain.crt
--determinate`. Under `--no-confirm` a failed install never reverts (the
volume is safe), but it copies itself to `/nix/nix-installer`, truncating
that binary to zero bytes if it *was* that file — fetch the release binary
again if so.

The window (done 2026-09-16; kept as the record of what was verified):

1. `mise run provision-indri` (full run). The first switch is driven by
   the *old* generation's `darwin-rebuild` (the fallback path), which still
   calls `activate-user`; 26.05 ships that as a deprecated stub, so the log
   shows a red `activate-user is deprecated` warning before `setting up
   /etc...`. That is expected, not a failure — the `.status` file decides.
2. Verify: `readlink /etc/static` points at the new generation; `scutil
   --dns` still shows `ts.net` → 100.100.100.100; `launchctl print gui/501`
   unchanged. The stale `/Library/LaunchDaemons/com.tailscale.tailscaled.plist`
   must be gone (activation removed it itself on 2026-09-16; `sudo rm` it
   by hand if it survives — it is not loaded).
3. Forge API responds, a registry push works, `mise run agent-health`
   passes.
4. Safety, immediately after `readlink /etc/static` has moved: delete
   `system-3…14` (`nix-env -p /nix/var/nix/profiles/system
   --delete-generations old`), the per-user `home-manager-*` links
   (`/etc/profiles/per-user/{erichblume,root}`) and root's. This removes
   the hazardous rollback targets — a safety action, not cleanup.

### Rollback drill (gen 16 → 15)

The machinery is proved without ever re-activating generation 14:

1. Scratch-edit `/etc/blumeops/darwin/indri` (one extra
   `environment.systemPackages` entry) and run `sudo darwin-rebuild switch
   --flake /etc/blumeops/darwin/indri#indri` → gen 16.
2. `sudo darwin-rebuild --rollback` (16 → 15), verify as above.
3. Switch forward (re-apply, scratch edit reverted), leaving the newest
   generation current.

### Reboot test

Done 2026-09-16. The first reboot found `org.nixos.activate-system` not
loading at boot and `/run/current-system` deleted: Background Task
Management had recorded the daemon as `Disposition: [enabled,
disallowed, notified]` (`sudo sfltool dumpbtm`). The verdict was a
**stale BTM record, not the plist shape**: `sudo sfltool resetbtm` (from
a Terminal on indri — it needs the Authorization Services prompt and
fails over ssh with `errAuthorizationInteractionNotAllowed`) followed by
a reboot flipped the disposition to `[enabled, allowed, notified]`. The
daemon now runs at boot (exit 0) and **`/run/current-system` survives
reboots**; every other background item stayed `allowed` after the reset.
The play's system-profile fallback stays in place — `/run/current-system`
is still absent before the first switch, and nix-managed user agents live
in `~/Library/LaunchAgents`, which launchd loads at login regardless.

A reboot also pops "Enter a password to unlock the disk Nix Store" at
login. **Cancel it** — the volume password is a random one in the System
keychain and the `systems.determinate.nix-store` daemon mounts `/nix`
with it moments later (verify with `mount | grep /nix`); the dialog is
loginwindow racing the daemon.

This is the only step that takes indri offline (forge, registry, every
`*.ops.eblu.me` route and the Fly proxy behind them). Pick a moment with
no talos session in flight and no CI run, and have Screen Sharing to
indri open *before* starting — nothing in `gui/501` serves until someone
logs in ([[restart-indri]]):

1. `ssh indri 'sudo fdesetup authrestart'` — unlocks FileVault for this
   one boot; without it the mini waits at the unlock screen for a
   password typed at the console.
2. ~2 min later the login window appears. Log in via Screen Sharing;
   dismiss the tailscaled dialog the first Tailscale SSH connection pops;
   start Amphetamine and AutoMounter.
3. `ssh indri 'readlink /run/current-system; sudo launchctl print
   system/org.nixos.activate-system | head -1'`, then the verification
   list above and `mise run services-check`.

Since the /etc-static boot-race fix (#1150), the window before the Nix Store
dialog is answered is the proof for the two consumers that do not tolerate
a dangling `/etc/static` link:

- `ssh indri` connects (a dangling sshd drop-in makes sshd's `Include`
  exit 1 and refuse every connection until the mount; the generation now
  declares no sshd drop-in).
- `scutil --dns` shows `ts.net` → 100.100.100.100 before login (the
  resolver is a real file the play writes, not a store symlink).

One-time, right after the first apply of that fix (the switch that drops
the old declarations): `ls -l /etc/resolver/ts.net` is a regular file,
`ls /etc/ssh/sshd_config.d` shows only Apple's `100-macos.conf`, and
`sudo sshd -t` passes.

## Rolling back a service flip (PRs 2–8)

Each service migration writes its plist at the same path ansible used,
under the same `mcquack.eblume.*` label (logrotate's globs and alloy's log
tails key on it). Once a service is flipped, its ansible role is skipped by
default (a role variable is off), so only the generation owns the plist.
When a generation changes a service's plist, the rollback order is fixed:
`sudo darwin-rebuild --rollback` **first**, then re-run the role with its
gate flipped — for logrotate, `mise run provision-indri -- --tags logrotate
-e logrotate_ansible_managed=true` — so ansible writes the plist back and
its restart handler reloads the agent. For the metrics flip (PR 4), re-run
all four roles the same way: `mise run provision-indri -- --tags
borgmatic_metrics,forgejo_metrics,jellyfin_metrics,zot_metrics -e
borgmatic_metrics_ansible_managed=true -e forgejo_metrics_ansible_managed=true
-e jellyfin_metrics_ansible_managed=true -e zot_metrics_ansible_managed=true`.
For the zot registry flip (PR 5), re-run `mise run provision-indri --
--tags zot -e zot_ansible_managed=true`. Unlike the textfile
collectors, zot is a real daemon: the registry is down between the
rollback and the ansible re-write. For the caddy flip (PR 6), re-run
`mise run provision-indri -- --tags caddy -e caddy_ansible_managed=true`
— the widest outage: every `*.ops.eblu.me` endpoint and the L4 routes
(2222/5433/5434 and the sifaka exporter ports) are down during the
window, and no CI runs land while the forge is unreachable.
Never ansible first — that would leave the old plist loaded under the new
generation.

What the rollback itself does depends on the target generation
(nix-darwin `modules/system/launchd.nix`, unchanged on master as of
2026-09-17): the user-launchd phase — including the loop that unloads and
deletes agents the target does not declare — is emitted only when the
target declares **at least one** user agent. Rolling back to a generation
with none (gen 19 → 18, the PR 2 case) leaves the nix plist loaded and
running the store script, which survives only as long as the newer
generation is a GC root; the ansible step is what actually replaces it.
Rolling back to a generation that keeps other agents (every flip after
PR 2) unloads and deletes the dropped ones, and the service is down until
ansible runs. Both cases were drilled on 2026-09-17 (blumeops#1125).

The gate variable must arrive as a boolean: the role's conditionals apply
`| bool`, so the `-e key=true` form above is fine; without the filter,
ansible-core 2.19 rejects the string with "Conditionals must have a boolean
result".

Verifying an agent after a flip or a rollback: `launchctl print
gui/501/mcquack.eblume.<name>` — `program =` names the owner (a
`/nix/store/…` path or ansible's) and `last exit code = 0`. `runs` is
the climbing signal for the collectors; for a daemon, activation's
reload is an unload+load, so the new instance starts at `runs = 1` —
the proof of the reload is the new pid, the rebuild log's
`reloading user service` line, and the daemon's own `received signal
15` log line at the switch timestamp. The `StandardOutPath` log is not
a signal; a quiet agent writes nothing.

## Window hygiene

A window contains exactly one PR: apply pending role merges by tag
(`--tags alloy,caddy,borgmatic,zot`) first, then the PR's
`provision-indri`. Halting between any two PRs leaves indri serving.

## Related

- [[indri]] - the box and its services
- [[restart-indri]] - shutdown and startup
- [[manage-lockfile]] - ringtail's lockfile flows
- [[agent-change-process]] - why agent PRs sit pending
