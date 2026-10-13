---
title: Seed Host Secrets from the Vault
modified: 2026-10-12
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
only part of this mechanism that runs unattended). Generated entries (like
`/etc/k3s/token`) mint once on first seed and are never rotated afterwards.
Anything a check cannot inspect is `UNKNOWN`, and `UNKNOWN` is a failure.

## Adding a new entry

Add the entry to `nixos/ringtail/secrets.json` (or
`darwin/indri/secrets.json`) — path, kind (`op` or `generated`), `op://` ref,
owner/group/mode, and the unit(s) to restart — and to the nix config that
references it. The flake invariant fails the flake-check build if the config
references a path the manifest does not declare, or the manifest declares a
path nothing references, so the two stay in lockstep. Then run
`mise run seed-secrets ringtail --dry-run`, and apply from gilbert.

## Failure modes

- **`UNKNOWN` is a failure.** A check that cannot see a file is red, not
  green — a partial picture of a secrets boundary invites a second surprise.
- **Tailscale SSH on indri returns exit 0 for everything**
  ([eblume/blumeops#1379](https://forge.ops.eblu.me/eblume/blumeops/issues/1379)).
  Every write is read back (owner, group, mode, sha256 of what was written);
  a read-back that disagrees is a hard failure.
- **Stray files are reported, never deleted.** A scratch file is more likely
  than a leaked secret, and deletion stays a human act.
- **Biometric required.** Apply refuses to run without a TTY, so CI can never
  run this — the vault credential is the thing the pattern removes from the
  apply path.

## See also

- [eblume/blumeops#1524](https://forge.ops.eblu.me/eblume/blumeops/issues/1524) — the mechanism issue
