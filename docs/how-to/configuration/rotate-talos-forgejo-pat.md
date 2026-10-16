---
title: Rotate the talos Forgejo bot PAT
modified: 2026-10-15
last-reviewed: 2026-10-15
tags:
  - how-to
  - secrets
  - talos
  - forgejo
---

# Rotate the talos Forgejo bot PAT

How to rotate the Forgejo PAT that the talos pod and the blumeops mise tasks use
to act as the `talos` bot on the forge (origin eblume/blumeops#1656; the
#1166 transcript incident is why the credential is arranged the way it is
below). The secret lives at `op://agents/talos-forgejo-token/api-token` — a
PAT on the Forgejo user `talos`, scopes `write:repository` + `write:issue`,
**minted as the `talos` user** so it can't exceed the bot's own repo access.
Consumers:

- the talos pod entrypoint (reads the token at pod boot, exports
  `FORGEJO_TOKEN`, seeds tea — pod sessions resume off the PVC);
- the blumeops mise tasks `request-run`, `verify-runs`, `lint-auto-apply`,
  `pending-deploys` (`FORGEJO_TOKEN` env with `op` read fallback).

Minting the successor needs the bot's **login password** — a Forgejo PAT
cannot mint its own successor (Forgejo mints over basic auth **as the user**),
so the mint rides the stored password copy. That bootstrap credential lives at
`op://blumeops-ci/talos-forgejo-bot/login-password`.

## When to rotate

- Every ~90 days (a talos cron files a `chore:` issue ~75 days out —
  established chore surface, see eblume/blumeops#1656)
- Immediately on any suspected exposure — e.g. the #1166 transcript incident

## One-time password migration

The step that makes the automated path possible. The login password used to
live in the **agents** vault at `op://agents/talos-forgejo-bot`, which every
talos session can read — that copy is exactly what leaked in #1166. Human
steps, on gilbert or via the 1Password UI:

1. **Create the item with a 1Password-generated password** (the new password
   never touches argv or shell history; `user_name` is not a secret):

   ```fish
   op item create --vault blumeops-ci talos-forgejo-bot \
       --user-name talos --generate-password
   ```

   (The 1Password UI equivalent works too.)

2. **Set it on the Forgejo `talos` account:** read the new password once
   (`op read op://blumeops-ci/talos-forgejo-bot/login-password` — terminal
   output only), then forge → log in as `talos` with the old password →
   Settings → Account → Change Password.

3. **Delete the old item:**

   ```fish
   op item delete --vault agents talos-forgejo-bot
   ```

Nothing in the pod reads the agents-vault copy, so deleting it is safe once
the new copy verifies (a dry-run + one live rotation proves it).

## Procedure

The automated path, from a machine with biometric `op` (gilbert) and a
kubectl that can reach the cluster (the operator's own):

```fish
mise run forge-bot-pat-rotate
```

The script refuses non-TTY runs without `--dry-run` (the warrant-gated CI
path, a later PR, passes `--ci`). What it does, numbered:

1. **Verify the current PAT** — repo GET of `eblume/research` (a repo the bot
   pushes to) through it, 200 and reporting the bot's push permission; a
   failure dies before anything is touched.
2. **Read the login password** from `op://blumeops-ci/talos-forgejo-bot/login-password` —
   the credential over which the mint rides.
3. **List the bot's tokens** via basic auth and print each as
   `  - name (id=N)` — names and ids only, never values. If the bot holds
   more than one non-`forge-bot-pat-*` token, the script dies here (before
   minting) — resolve those by hand first. The run also proves that the
   vault's current value matches some live token by `token_last_eight`
   before the mint, which makes the single unprefixed token provably
   revocable as a predecessor: it is either the vault's incumbent (the
   first run's hand-over) or the pending delayed revoke of an earlier
   `--skip-roll` / failed-roll run.
4. **Mint `forge-bot-pat-<ts>`** (scopes unchanged).
5. **Prove the new PAT BEFORE any write**: repo GET through it (200, push
   permission) **and** it appears in the user's token list via basic auth
   (the ownership check — mirrored from `horkos-forge-provision`'s
   `verify_new_pat`). If that proof or the vault write fails, the script
   re-reads the vault (a failed `op item edit` may have landed) and revokes
   the fresh token before dying — a live PAT that no consumer knows about is
   never left behind. The cleanup catches every exception (a missed
   biometric prompt included) and re-raises the original error.
6. **Write the vault**: `op://agents/talos-forgejo-token/api-token` + set the
   item's `expires` field to the next-due date (`--days`, default 90).
7. **Roll the talos pods**:
   `kubectl -n talos rollout restart deployment/talos`
   then `rollout status deployment/talos --timeout=300s` — kubectl's own config
   as-is outside `--ci` (`$KUBECONFIG` or `~/.kube/config`); only the CI
   path falls back to the `blumeops-ci/k3s-run-script` bound token
   (loopback-only, a 0600 temp file). This roll is what picks up the new token.
8. **Revoke every predecessor**: all other `forge-bot-pat-*` tokens, plus the
   single unprefixed incumbent the first run takes over (the vault's current
   token predates the prefix).
9. **Post-check**: exactly one live token for the bot (the new one), and the
   old PAT now 401s.

Fail-safe ordering: a failure anywhere before the revoke step leaves every
consumer working — the old token is only revoked after the new one is verified
**and** the pods have been rolled; `--skip-roll` defers the revoke instead
(the live pods still need the old token — see below).

## --skip-roll (when the script can't roll)

The roll step needs a kubectl that can reach the cluster API: either
kubectl's own config (`$KUBECONFIG` or `~/.kube/config` — on gilbert the
operator's own kubectl works as-is) or, in the warrant CI path, the
`k3s-run-script` bound token in `blumeops-ci` (loopback-only, ringtail's
priv runner). When no kubectl can reach the cluster, use `--skip-roll`.
The tradeoff, stated plainly: **the run stops after the vault write and
revokes nothing** — the predecessors stay live (delayed revoke; the next
run cleans them up) precisely because the live talos pods still need the
old token until they are rolled. Roll immediately after the run
completes:

```fish
kubectl -n talos rollout restart deployment/talos
```

Until the roll, new sessions read the new token from the vault while live
sessions run the old one — both work. Until the next run, the bot holds
two or more live tokens (one per skipped run; harmless: both scopes are
the bot's own, and the run's post-check after a full rotation still asserts
the one-live-token invariant).

## Debugging

### The current token does not authenticate

Check the vault item, and whether a rotation half-finished: if the vault has a
token that 401s while the pods work, the pods are running a still-valid old
token and the chain is fine — roll them. If nothing authenticates, the chain
is broken: worst case, mint by hand in the Forgejo UI as the `talos` account
and `op item edit` the vault item, then roll the pods.

### login password not readable

The migration isn't done (the password is still only in the agents vault), or
you're in the warrant path without `BLUMEOPS_CI_OP_TOKEN`, which the script
needs to read `blumeops-ci` items. See [One-time password migration](#one-time-password-migration).

### rollout fails

- `kubectl` not on PATH → re-run with `--skip-roll` and roll the pods
  yourself.
- in the CI path, the `k3s-run-script` bound token is loopback-only
  (ringtail's priv runner) — the manual path never hits this; on the manual
  path kubectl uses your own config as-is.
- k3s token expired → re-mint the `k3s-run-script` bound token per
  [docs/reference/services/horkos.md](../../../reference/services/horkos.md).

## Related

- [[rotate-gandi-pat]] — sibling rotation ceremony (Gandi PAT)
- [[rotate-fly-deploy-token]] — sibling rotation ceremony (Fly.io token)
- [[agents-forgejo-bot]] — the bot's reference card
- eblume/blumeops#1656 — the chore that files the rotation
