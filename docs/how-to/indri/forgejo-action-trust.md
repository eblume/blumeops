---
title: Forgejo action trust
modified: 2026-10-24
last-reviewed: 2026-10-24
tags:
  - how-to
  - indri
---

# Forgejo action trust

The `mcquack.eblume.forgejo-action-trust` launchd user agent (declared in
`darwin/indri/configuration.nix`) reconciles the Forgejo "always trust" set —
the `action_user` rows behind [[runners-and-trust]] — to the derived
declaration from `forge/action-trust.nix` (eblume/blumeops#1846). It runs at
every generation apply (RunAtLoad) and daily at 05:45.

## What a run does

1. Resolves the collaborator (`talos`) and each declared repo in `forgejo.db`
   by name; any missing or ambiguous id aborts the run.
2. Plans the diff: *created* (declared repo with no row), *refreshed*
   (declared repo with a trusted row — `last_access` touched), *removed*
   (every `action_user` row outside the declared set — any user's).
3. Live mode (the default) applies it as one `BEGIN IMMEDIATE … COMMIT`
   transaction; dry-run logs the plan and writes nothing to forgejo.db —
   the prom file then carries the *planned* counts (its HELP line says so).

Log and node_exporter textfile:
`/opt/homebrew/var/log/mcquack.forgejo-action-trust.log` (stdout+stderr, one
timeline) and
`/opt/homebrew/var/node_exporter/textfile/forgejo-action-trust.prom`
(`forgejo_action_trust_run_success`, `forgejo_action_trust_rows`).

## Reading drift

A `remove user=… repo=…` line for an undeclared repo means a manual "approve
and always trust" click happened there — the reconcile undoes it within a
day. That is the point of the full reconcile, not a fault.

## The 90-day expiry

Forgejo's weekly `RevokeInactiveActionUser` job drops a trusted row untouched
for 90 days; the daily leg refreshes `last_access` for every declared row, so
a quiet repo no longer lapses. Check it ran:

```sh
sqlite3 /Users/erichblume/forgejo/data/forgejo.db \
  "SELECT max(last_access) FROM action_user
   JOIN user u ON u.id = action_user.user_id
   WHERE lower(u.name) = 'talos'"
```

A value within the last day means the daily leg ran.

## Two human tests

- Undeclared row: insert one and watch the next daily run delete and log it:

  ```sql
  INSERT INTO action_user (user_id, repo_id, trusted_with_pull_requests, last_access)
  VALUES ((SELECT id FROM user WHERE lower(name) = 'talos'),
          (SELECT id FROM repository WHERE owner_name = 'eblume' AND name = '<repo>'),
          1, strftime('%s', 'now'));
  ```

- Backdated row: set a declared repo's row 91 days back and confirm the next
  run refreshes it past expiry (`RevokeInactiveActionUser` does not fire):

  ```sql
  UPDATE action_user SET last_access = strftime('%s', 'now') - 91 * 86400
  WHERE user_id = (SELECT id FROM user WHERE lower(name) = 'talos')
    AND repo_id = (SELECT id FROM repository WHERE owner_name = 'eblume' AND name = '<repo>');
  ```

## Live mode and the dry-run-first rule

The agent runs live — `forgejoActionTrustDryRun = false` in
`darwin/indri/configuration.nix` (flipped after the first applied
dry-run's log was reviewed, eblume/blumeops#1846). The dry-run-first rule
still applies to any change to the reconcile: ship it with `true`, review
the applied plan's log, then flip it back and re-apply ([[provision]]).
