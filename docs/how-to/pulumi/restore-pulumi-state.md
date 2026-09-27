---
title: Restore Pulumi State
modified: 2026-09-27
last-reviewed: 2026-09-27
tags:
  - how-to
  - pulumi
  - backup
---

# Restore Pulumi State

Restore a Pulumi Cloud stack (state + config) from the nightly borg backups.
Use this when a stack is deleted or corrupted, or when the Pulumi Cloud
account itself is lost.

## Why the exports are in plaintext

Pulumi Cloud encrypts stack secrets with a per-stack service key it controls.
A plain `pulumi stack export` therefore stays encrypted to the *source*
account: after losing it, the ciphertext cannot be decrypted, and
`pulumi stack import` fails on it. So the backups export with
`--show-secrets` (state) and `pulumi config --show-secrets` (config secrets,
which are not part of state at all) and rely on the borg repository
encryption — repokey, local [[sifaka]] + BorgBase offsite — as the
compensating control. The values also have bounded lifetimes: the Pulumi
access token rotates every 20 days, the Tailscale auth keys it can contain
expire in 90 days and are re-minted by the next `pulumi up` anyway.

## Getting the dumps

Exports are ferried to indri at `~/.local/share/borgmatic/k8s-dumps/` each
night before the 02:00 backup and ride in both borg repositories:

| File (staged name) | Content |
|--------------------|---------|
| `pulumi-tail8d86e-state.db` | `pulumi stack export --show-secrets` of `blumeops-tailnet/tail8d86e` |
| `pulumi-tail8d86e-config.db` | `pulumi config --show-secrets` of the same |
| `pulumi-eblu-me-state.db` | state of `blumeops-dns/eblu-me` |
| `pulumi-eblu-me-config.db` | config of the same |

(The ferry names every file-dump target `.db` regardless of content — the
state files are JSON, the config files plain text.)

```bash
borg list /Volumes/backups/borg/repo            # find a recent archive
mkdir -p /tmp/pulumi-restore
borg extract /Volumes/backups/borg/repo:<archive> <staged-path-prefix> \
  -o /tmp/pulumi-restore
ls /tmp/pulumi-restore   # the four pulumi-* files (or extract single files)
```

The staged path prefix is `.local/share/borgmatic/k8s-dumps/` inside the
archive — check the real paths with `borg list`.

## Restoring into a new (or same) account

`pulumi stack import` re-encrypts the decrypted secrets under the *target*
stack's secrets provider, so the destination decides the scheme. The
provider cannot be set on import — it is fixed at stack creation:

```bash
export PULUMI_CONFIG_PASSPHRASE='...'   # your choice; keep it in 1Password
pulumi login                            # Pulumi Cloud, or a local backend
pulumi stack init <name> --secrets-provider passphrase
pulumi stack import --file <state.json>
```

Then re-add the stack config (re-encrypts under the new stack's provider):

```bash
pulumi config set --secret tailscale:apiKey <value>   # tailnet stack
pulumi config set blumeops-dns:domain eblu.me         # dns stack (plaintext values)
```

The config dumps are `pulumi config --show-secrets` output; re-add the
`secret`-marked values with `pulumi config set --secret`.

Then run `pulumi up --refresh` from the project directory
(`pulumi/tailscale/`, `pulumi/gandi/`) with the provider credentials
exported — see [[pulumi]]'s Authentication section.

## What re-mints, what doesn't

- **Tailscale auth keys** (`TailnetKey` resources, e.g. the flyio-proxy and
  talos agent keys) are outputs minted by the program. Importing state does
  **not** re-mint them; the next `pulumi up` does. Old keys expire after 90
  days, and an expired key in state is not itself a problem — the resource
  recreates on drift. If a key was consumed before restore, just `up`.
- **Gandi PAT / Tailscale OAuth client** live in 1Password and are fed as
  *config*, not state — unaffected by the account loss; just re-export them
  into the environment when running `pulumi up`.
- **Tailscale ACL + device tags, DNS records**: pure state; imported intact
  and reconciled by `up`.

## Caveats

- Import with a CLI ≥ the one that wrote the checkpoint (3.237.0 in the
  backup image): a newer CLI imports older checkpoints, not the reverse.
- Do not `pulumi up --refresh` before you are ready for it to apply
  drift — the tailnet ACL resource is a full overwrite, so a stale local
  `policy.hujson` rewrites the live ACL. Restore from a fresh blumeops
  checkout at the matching commit.
- The exported state names the original stack's URNs; importing into a
  differently *named* stack is fine (URNs embed the stack name the same way
  on both sides), but keep the project name unchanged or URNs will not
  match.

## Related

- [[pulumi]] — projects, stacks, and the token
- [[borgmatic]] — where the dumps live
- [[manage-eblu-me-dns]], [[update-tailscale-acls]] — the stack workflows
