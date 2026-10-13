---
title: Seed Host Secrets from the Vault
modified: 2026-10-13
last-reviewed: 2026-10-12
tags:
  - how-to
  - operations
  - security
---

# Seed Host Secrets from the Vault

`mise run seed-secrets` is human-run on gilbert (biometric 1Password) and
seats vault secrets as host files the nix config references by path. The apply
path itself — `nixos-rebuild` / `darwin-rebuild` — reads no vault: it
references these files by path, which is the property that lets host config
merge-apply like ArgoCD. The per-host `secrets.json` manifest is the
declared-state owner (see [[declared-state-files]]); the per-host flake
invariant keeps it in lockstep with the config (see [[add-a-flake-invariant]]).

## When to run it

- A new host file the nix config references is declared in the manifest.
- Rotation of one item — `--only <path>` — without touching the rest.
- After a vault value changes (a runner registration token, a service
  account credential).

## Commands

```sh
mise run seed-secrets ringtail            # apply: read the vault (biometric), write, restart units
mise run seed-secrets ringtail --check   # vault-free drift gate: verify ownership/mode, scan for stray files
mise run seed-secrets ringtail --dry-run # report what an apply would do; write nothing
mise run seed-secrets ringtail --only /etc/forgejo-runner/priv.env
```

`--check` needs no vault and no TTY, so it is the weekly drift gate (and the
only part of this mechanism that runs unattended). Anything a check cannot
inspect is `UNKNOWN`, and `UNKNOWN` is a failure.

Every remote command runs as root through `sudo -n` over ssh, so the ssh
user needs passwordless sudo on the host (ringtail's `eblume` has it).

Vault values are written newline-stripped, the same bytes ansible's
`pre_tasks` wrote.

Generated entries (like `/etc/k3s/token`) mint once and are never rotated.
Minting asks for confirmation and restarts nothing. An absent generated file
on a live host is almost always a lost file, not a fresh host: for the k3s
token, restore it from `/var/lib/rancher/k3s/server/token`. A new value would
not match the token the cluster's bootstrap data is encrypted with.

## The weekly check

The `seed-secrets-check.yaml` workflow runs `seed-secrets ringtail --check` on
the nix-container-builder runner (ringtail in host mode) Sunday 05:30 UTC and
on every main push that touches the manifest or the script. The job holds no
credentials — the check reads no vault — and invokes the script directly
rather than through `mise run`, which is `[human]`-fenced for agent pods.

The check needs an ssh + passwordless-sudo route from the runner to the host.
The runner runs as the DynamicUser `gitea-runner`, which has no route today,
so until one is granted the runs fail loudly with
`UNKNOWN ssh + sudo route to ringtail` — a check that cannot see is a failure,
and the loud red is what keeps the gap from going quiet (blumeops#1515). From
gilbert the check works today on eblume's route.

## Adding a new entry

Add the entry to `nixos/ringtail/secrets.json` (or
`darwin/indri/secrets.json`) — path, kind (`op` or `generated`), `op://` ref,
owner/group/mode, and the unit(s) to restart — and to the nix config that
references it. The flake invariant fails the flake-check build if the
manifest declares a path nothing references, or if one of the reference
sites it knows about uses an undeclared path. On ringtail those are
`services.k3s.tokenFile`, the `gitea-actions-runner` instances' `tokenFile`,
and `/etc/agents/op-token`. It does not scan every option, so a new kind of
reference site (an `EnvironmentFile`, a `credentialsFile`) must be added to
`referenced` in `invariants.nix` in the same PR. Then run
`mise run seed-secrets ringtail --dry-run`, and apply from gilbert.

## Failure modes

- **`UNKNOWN` is a failure.** A check that cannot see a file is red, not
  green — a partial picture of a secrets boundary invites a second surprise.
- **Tailscale SSH on indri returns exit 0 for everything**
  ([eblume/blumeops#1379](https://forge.ops.eblu.me/eblume/blumeops/issues/1379)).
  Every write is read back (owner, group, mode, sha256 of what was written);
  a read-back that disagrees is a hard failure.
- **Stray files are reported, never deleted.** A scratch file is more likely
  than a leaked secret, and deletion stays a human act. A failed write can
  leave `<path>.seedtmp` holding the value. `--check` reports it as a
  stray; delete it by hand.
- **indri is refused while its manifest is non-empty.** The darwin write and
  restart legs wait for the forgejo_runner role to move to nix
  ([eblume/blumeops#1213](https://forge.ops.eblu.me/eblume/blumeops/issues/1213)).
- **Biometric required.** Apply refuses to run without a TTY, so CI can never
  run this — the vault credential is the thing the pattern removes from the
  apply path.

## See also

- [eblume/blumeops#1524](https://forge.ops.eblu.me/eblume/blumeops/issues/1524) — the mechanism issue
