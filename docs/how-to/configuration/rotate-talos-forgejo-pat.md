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

1. **Generate a new random password:**

   ```fish
   openssl rand -base64 32
   ```

2. **Set it on the Forgejo `talos` account:** forge → log in as `talos` with
   the old password → Settings → Account → Change Password.

3. **Create the item** (concealed field):

   ```fish
   op item create "talos-forgejo-bot" --vault blumeops-ci --category login \
     "user_name[username]=talos" "login-password[password]=<new>"
   ```

4. **Delete the old item:**

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
   minting) — resolve those by hand first.
4. **Mint `forge-bot-pat-<ts>`** (scopes unchanged).
5. **Prove the new PAT BEFORE any write**: repo GET through it (200, push
   permission) **and** it appears in the user's token list via basic auth
   (the ownership check — mirrored from `horkos-forge-provision`'s
   `verify_new_pat`).
6. **Write the vault**: `op://agents/talos-forgejo-token/api-token` + set the
   item's `expires` field to the next-due date (`--days`, default 90).
7. **Roll the talos pods**:
   `kubectl --kubeconfig <tmp> -n talos rollout restart deployment/talos`
   then `rollout status deployment/talos --timeout=300s` — kubeconfig from
   `$KUBECONFIG`, else the `blumeops-ci/k3s-run-script` bound token read to a
   0600 temp file; this roll is what picks up the new token.
8. **Revoke every predecessor**: all other `forge-bot-pat-*` tokens, plus the
   single unprefixed incumbent the first run takes over (the vault's current
   token predates the prefix).
9. **Post-check**: exactly one live token for the bot (the new one), and the
   old PAT now 401s.

Fail-safe ordering: a failure anywhere before step 8 leaves every consumer
working — the old token is only revoked after the new one is verified **and**
the pods have been rolled (or `--skip-roll` with a loud warning).

## --skip-roll (when the script can't roll)

The roll step needs a kubectl that can reach the cluster API: either
`$KUBECONFIG` (from gilbert, the operator's own kubectl works as-is) or the
`k3s-run-script` bound token in `blumeops-ci` (its server URL is
loopback-only, so it resolves only on ringtail's priv runner). When neither
is available, use `--skip-roll` — with the tradeoff stated plainly: the
script still revokes the old token at the end, so the live talos pods keep a
dead token in env until you roll them. Roll immediately after the run
completes:

```fish
kubectl -n talos rollout restart deployment/talos
```

In the gap between revoke and roll, the live sessions' git/forge calls
401; fresh sessions and the rolled pods read the new token from the vault
at boot.

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
- the k3s-run-script bound token can't reach the API (its server URL is
  loopback-only — it resolves on ringtail's priv runner, not from gilbert) →
  run with your own `$KUBECONFIG`, or `--skip-roll` + a manual roll.
- k3s token expired → re-mint the `k3s-run-script` bound token per
  [docs/reference/services/horkos.md](../../../reference/services/horkos.md).

## Related

- [[rotate-gandi-pat]] — sibling rotation ceremony (Gandi PAT)
- [[rotate-fly-deploy-token]] — sibling rotation ceremony (Fly.io token)
- [[agents-forgejo-bot]] — the bot's reference card
- eblume/blumeops#1656 — the chore that files the rotation
