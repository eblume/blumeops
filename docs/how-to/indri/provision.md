---
title: Provision Indri
modified: 2026-09-15
last-reviewed: 2026-09-15
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
   service roles.


## The rebuild tag (zero-prompt apply)

The checkout and rebuild tasks are tagged `rebuild`, so
`mise run provision-indri -- --tags rebuild` applies a new generation with no
1Password prompts (a full run costs ~20, one per `op read`). The tasks
checkout the bound SHA into a root-owned `/etc/blumeops` (HTTPS from the
forge, forced) and run `darwin-rebuild switch --flake
/etc/blumeops/darwin/indri#indri` detached via `nohup` — log at
`/var/log/indri-rebuild/<sha>.log` plus a `.status` sidecar — then wait
(bounded, 60 min) and fail with the log embedded on non-zero exit.

The play resolves `darwin-rebuild` from `/run/current-system`, falling back
to the system profile (`/nix/var/nix/profiles/system/sw/bin`). Before the
first switch there is no `/run/current-system` at all (it appears only after
an activation has run); whether the symlink survives a reboot is what the
reboot test below answers.

If a run dies mid-rebuild (session drop, pod replacement, the wait
timing out), the switch keeps running detached and will have left
`/var/log/indri-rebuild/<sha>.status` (the exit code) and `.log`. The play
only rebuilds when the checkout changes, so re-running the same commit
reports clean and does not retry: read the status file before re-applying,
and fix forward with a new commit if the switch failed.

## Pre-apply check: indri-flake-check

`mise run indri-flake-check` builds `.#darwinConfigurations.indri.system` on
indri itself, at the local HEAD — the exact commit `provision-indri` would
deploy. It must run on the box: no off-box host can evaluate aarch64-darwin.
Run it from any blumeops checkout before a window.

## CI coupling

The Indri Flake Check workflow (`.forgejo/workflows/indri-flake-check.yaml`)
runs the same build on the indri runner for every PR and push to main,
against indri's own store — the check lives where the target platform is,
because ringtail cannot evaluate aarch64-darwin. The runner's PATH carries
`/nix/var/nix/profiles/default/bin` for this (forgejo-runner.plist.j2);
erichblume is not a trusted nix user, which is fine for a flake build. The
cached store keeps flake-untouched PRs fast.

## First switch (one-way)

The first generation changes only the target of `/etc/static` (equivalent
content, re-owned from the dormant 25.05 generation) and declares no
services or agents. The switch is one-way by necessity: the old generation
(system-14) must never be re-activated — its etc check carries the
pre-Tahoe zsh hash list and aborts on the post-Tahoe `/etc/zshrc`, and it
declares `services.tailscale`, which would load a second tailscaled beside
the Homebrew root daemon.

Step 0, before the window (human, on indri): the Determinate upgrade —
`sudo installer -pkg Determinate.pkg -target /` from
`https://install.determinate.systems/determinate-pkg/stable/Universal` —
with a `tar` of the `/etc/static` targets as insurance, then re-verify
`nix store info`, a trivial `nix build`, and
`launchctl list | grep mcquack` unchanged.

The window:

1. `mise run provision-indri` (full run).
2. Verify: `readlink /etc/static` points at the new generation; `scutil
   --dns` still shows `ts.net` → 100.100.100.100; `launchctl print gui/501`
   unchanged. The stale `/Library/LaunchDaemons/com.tailscale.tailscaled.plist`
   must be gone — nix-darwin's removal loop diffs against
   `/run/current-system/Library/LaunchDaemons`, which did not exist before
   the first switch, so activation never removes it: `sudo rm` it by hand
   (it is not loaded).
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

One reboot in a window: confirms the new generation's activation loads at
boot (why `org.nixos.activate-system` stopped loading on the old one is
open) and that `/run/current-system` survives — which decides which
`darwin-rebuild` path the play uses going forward (the fallback above).

## Rolling back a service flip (PRs 2–8)

Each service migration writes its plist at the same path ansible used,
under the same `mcquack.eblume.*` label (logrotate's globs and alloy's log
tails key on it). When a generation changes a service's plist, the rollback
order is fixed: `sudo darwin-rebuild --rollback` **first** (nix-darwin
unloads and deletes agents the target generation does not declare, whoever
wrote the plist last — the service is down), then
`mise run provision-indri -- --tags <svc>` (ansible writes the plist back).
Never ansible first — that would leave the old plist loaded under the new
generation.

## Window hygiene

A window contains exactly one PR: apply pending role merges by tag
(`--tags alloy,caddy,borgmatic,zot`) first, then the PR's
`provision-indri`. Halting between any two PRs leaves indri serving.

## Related

- [[indri]] - the box and its services
- [[restart-indri]] - shutdown and startup
- [[manage-lockfile]] - ringtail's lockfile flows
- [[agent-change-process]] - why agent PRs sit pending
