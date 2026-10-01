---
title: Restore Pulumi State
modified: 2026-10-01
last-reviewed: 2026-10-01
tags:
  - how-to
  - pulumi
  - backup
---

# Restore Pulumi State

Restore a Pulumi Cloud stack's state from the nightly borg backups.
Use this when a stack is deleted or corrupted, or when the Pulumi Cloud
account itself is lost.

## Why the exports are in plaintext

Pulumi Cloud encrypts stack secrets with a per-stack service key it controls.
A plain `pulumi stack export` therefore stays encrypted to the *source*
account: after losing it, the ciphertext cannot be decrypted, and
`pulumi stack import` fails on it. So the backups export with
`--show-secrets` and rely on the borg repository encryption — repokey, local [[sifaka]] + BorgBase offsite — as the
compensating control. The values also have bounded lifetimes: the Pulumi
access token rotates every 20 days, the Tailscale auth keys it can contain
expire in 90 days and are re-minted by the next `pulumi up` anyway.

## Getting the dumps

Exports are ferried to indri at `~/.local/share/borgmatic/k8s-dumps/` each
night before the 02:00 backup and ride in both borg repositories. A missing or
empty export on a given night is skipped by its ferry (the `pv:` ferry mode is
self-contained) rather than aborting the whole nightly, so the staged file then
holds the previous night's export:

| File (staged name) | Content |
|--------------------|---------|
| `pulumi-tail8d86e-state.db` | `pulumi stack export --show-secrets` of `blumeops-tailnet/tail8d86e` |
| `pulumi-eblu-me-state.db` | state of `blumeops-dns/eblu-me` |

(The ferry names every file-dump target `.db` regardless of content — these
are JSON.)

Stack config is not backed up here, because nothing in it is only in Pulumi
Cloud: plain values are in `pulumi/<project>/Pulumi.<stack>.yaml` in git, and
the provider secrets come from the Pulumi ESC environments named there, whose
definitions are in `pulumi/esc/` and whose values are in 1Password.

Stream the files straight out of the archive with `borg extract --stdout`:
the extract runs *on indri*, so without `--stdout` the files would land in
indri's working directory rather than on the host you are restoring from.

```bash
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg list /Volumes/backups/borg --last 1'   # newest archive

ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg extract --stdout /Volumes/backups/borg::<archive> \
  Users/erichblume/.local/share/borgmatic/k8s-dumps/pulumi-tail8d86e-state.db' \
  > pulumi-tail8d86e-state.json
ssh indri 'BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg extract --stdout /Volumes/backups/borg::<archive> \
  Users/erichblume/.local/share/borgmatic/k8s-dumps/pulumi-eblu-me-state.db' \
  > pulumi-eblu-me-state.json
```

(The staged paths are relative to the archive root — no leading slash;
`borg list` shows the same paths. Extract a single file by naming just it.
The same one-liner works against the BorgBase offsite repository instead of
`/Volumes/backups/borg`.)

## Restoring into a new (or same) account

`pulumi stack import` re-encrypts the decrypted secrets under the *target*
stack's secrets provider, so the destination decides the scheme, and the
provider cannot be set on import — it is fixed at stack creation. But the
export JSON still carries the *source* stack's `deployment.secrets_providers`
field, and `import` trusts it: as-is, it tries to build the Pulumi Cloud
service secrets manager and dies without an account token
(`could not find access token for https://api.pulumi.com`), and simply
deleting the field is not enough — with secrets present and no provider the
CLI panics on `attempt to encrypt value`. (A secret-free export imports fine
with the field deleted.) The fix is to replace the field with the *target*
stack's provider before importing.

Scratch or real, the recipe is the same — a fresh backend, a stack created
with the passphrase provider, and the rewrite to that provider's salt:

```bash
export PULUMI_CONFIG_PASSPHRASE='...'   # your choice; keep it in 1Password
mkdir pulumi-restore && cd pulumi-restore
echo 'name: <project>' > Pulumi.yaml    # blumeops-tailnet or blumeops-dns
pulumi login file://$PWD/backend        # or Pulumi Cloud
pulumi stack init <stack> --secrets-provider passphrase
# stack init writes the salt to Pulumi.<stack>.yaml:
salt=$(sed -nE 's/^encryptionsalt: *(.*)$/\1/p' Pulumi.<stack>.yaml)
jq --arg s "$salt" '.deployment.secrets_providers={type:"passphrase",state:{salt:$s}}' \
  pulumi-tail8d86e-state.json > pulumi-tail8d86e-state.import.json
pulumi stack import --stack <stack> --file pulumi-tail8d86e-state.import.json
pulumi stack export --show-secrets   # sanity: resources + secrets decrypt
```

The backup files hold plaintext secrets, so the rewrite (not the source
passphrase) is what makes them importable; afterwards they are ciphertext
under the target's provider. Restoring *into* Pulumi Cloud works the same
shape — point the field at the new stack's provider — but that path is
untested; the passphrase path was exercised end to end on 2026-10-01 (both
stacks imported, all secrets decrypting).

The stack config comes back with the repo: `Pulumi.<stack>.yaml` holds the
plain values and the `environment:` import of the ESC environment that serves
the provider secrets. In a new account, recreate those environments first with
`mise run pulumi-esc-sync` (see [[pulumi]]'s Authentication section).

Then run `pulumi up --refresh` from the project directory
(`pulumi/tailscale/`, `pulumi/gandi/`).

## What re-mints, what doesn't

- **Tailscale auth keys** (`TailnetKey` resources, e.g. the flyio-proxy and
  talos agent keys) are outputs minted by the program. Importing state does
  **not** re-mint them; the next `pulumi up` does. Old keys expire after 90
  days, and an expired key in state is not itself a problem — the resource
  recreates on drift. If a key was consumed before restore, just `up`.
- **Gandi PAT / Tailscale OAuth client** live in 1Password and reach the
  stacks through ESC as *config*, not state — unaffected by the account loss
  once `pulumi-esc-sync` has recreated the environments.
- **Tailscale ACL + device tags, DNS records**: pure state; imported intact
  and reconciled by `up`.

## Verifying the restore path

To prove the backups are restorable without touching the live org, restore
into a scratch `file://` backend exactly as above — a fresh `Pulumi.yaml`
with only `name: <project>`, `stack init <stack> --secrets-provider
passphrase`, the `secrets_providers` rewrite, then the import. Verify the
resource count matches the export and that `export --show-secrets` decrypts
the secrets. `mise run pulumi-restore-check` (see [[mise-tasks]]) automates
this against the newest borg archive — it streams both exports out of indri,
imports them into throwaway `file://` backends, reports resource and secret
counts, and shreds the extracted files.

## Caveats

- Import with a CLI ≥ the one that wrote the checkpoint (3.237.0 in the
  backup image): a newer CLI imports older checkpoints, not the reverse.
- Do not `pulumi up --refresh` before you are ready for it to apply
  drift — the tailnet ACL resource is a full overwrite, so a stale local
  `policy.hujson` rewrites the live ACL. Restore from a fresh blumeops
  checkout at the matching commit.
- Restore into a stack with the **same project and stack name**: URNs embed
  both, and import refuses anything else
  (`resource '…' is from a different stack (tail8d86e != restore-tail8d86e)`).
  The `--force` override exists; do not use it. A scratch verification
  therefore needs a separate backend (a `file://` directory), not a renamed
  stack in the live org.

## Related

- [[pulumi]] — projects, stacks, and the token
- [[borgmatic]] — where the dumps live
- [[manage-eblu-me-dns]], [[update-tailscale-acls]] — the stack workflows
