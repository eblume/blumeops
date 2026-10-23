---
title: Talos v0.5 — indri Ansible retirement (V5-83)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
  - indri
---

# Indri Ansible retirement (V5-83)

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

The design for finishing indri's move off Ansible, written into the repo
before its child Issues are filed. It replaces the umbrella eblume/blumeops#1535
and its last child #1730, both closed for the v0.5 clean slate; those threads
remain the history.

## Role in v0.5: a parallel lane and the control group

V5-83 runs alongside the waves, not inside them. One child Issue is open at a
time; the next is filed when the previous closes, so the chain needs neither
`wait_for` nor `!!blocked-on`.

It is also the **control group**. At each wave checkpoint, record one line:
"V5-83 under the new capability: better / same / worse, and why". The
question is whether what v0.5 has shipped so far gives good outcomes on work
unrelated to v0.5 itself.

**Fences:**

- Group 8 (borgmatic) stays clear of V5-05, which edits the borgmatic role to
  back up the talos store.
- The chain only removes Ansible; it adds no new files under `ansible/`, so
  it never trips V5-32's `no-new-ansible` ratchet. Edits
  to existing files during a retirement are allowed by the ratchet's
  definition.

## North star

Every indri role leaves Ansible for the nix-darwin generation
([[provision]]). Secrets become host-resident files seeded once by
`mise run seed-secrets`. Runner topology comes from `forge/runners.json`.
Merged no-vault config applies itself: the merge to main is the approval,
`provision-indri.yaml` runs from the merge SHA, and
`/var/log/indri-rebuild/<sha>.status` is the witness ([[auto-apply]]).
Indri's full Ansible play ends when the last role is gone.

**Vocabulary for each item:**

- **CP** — pure control plane: PR and CI, zero box acts. The merge applies it.
- **seed** — exactly one biometric `mise run seed-secrets indri` session from
  gilbert, then the apply.

## Done

- A. `forgejo_actions_secrets` (op reads moved into forge-reconcile)
- B. Homebrew adoption
- 1. `forgejo_runner` (#1528, #1718 merged)
- 2. The four metrics roles (#1700)
- heph's daemon legs (#1655, #1692): the LaunchAgent is generation-owned and
  its authorized-sub is a seed manifest entry.

## Remaining, in order

Each is one child Issue, opened as its predecessor closes.

3. **`logrotate`, `netconsole`, `cv`, `docs`, heph remnant** — all CP, no
   seed (verified on #1730). logrotate is already flipped (role default-off,
   kept only as the rollback re-writer). heph keeps only the PWA checkout and
   data dir. netconsole needs a new nix-darwin unit at the same label, plist
   and log paths (Alloy tails them). cv and docs choose between fetching the
   artifact in the generation and a documented manual install, and must
   rewire horkos's `release-targets.json` (cv), `caddy-render-check` (both)
   and `cut-release`'s `docs_version` hook (docs). #1730's plan comment holds
   the full analysis.
4. **`alloy`, `zot`** — alloy CP; zot seed (one file, its OIDC credentials).
   Both units are already generation-owned. The zot binary stays the source
   build at `~/code/3rd/zot`.
5. **`caddy`** — seed (one file, the Gandi PAT, from a different vault; the
   seed manifest carries the full reference). Retires Caddyfile rendering.
   Highest visibility; the seven blackbox probes are the witness.
6. **`devpi`, `jellyfin`** — devpi CP; jellyfin seed (one file, the SSO
   client secret). The jellyfin binary stays host-resident.
7. **`forgejo`** — seed (three files already host-resident in `app.ini`).
   `app.ini` becomes a nix template. One forge restart; drill the rollback
   direction first. The binary stays source-built.
8. **`borgmatic`, last** — seed (`~/.pgpass`, the BorgBase key) plus the
   passphrase declared-existing. Last because #1484 changes the BorgBase
   key's principal and a key file should be seeded once. Witness: one real
   create to a fresh `borgmatic.prom`. Kept clear of V5-05.

## Carried over

- Chezmoi dotfiles via home-manager, after the role list.
- GUI-login-session dependency: no auto-login of `erichblume`; promote the
  critical agents to daemons, decided in its own plan, last.
- Delete `~/code/3rd/caddy` on indri and prune its mirrors (a human step).
- Forge lineage: deferred to the next Forgejo upgrade.

## Standing rules

- `--tags rebuild` is the apply; `nix eval` before every scratch switch.
- `readlink /nix/var/nix/profiles/system` for the generation; the `.status`
  file decides success, not the run state.
- Labels and paths exact; no `/run/current-system` assumptions.
- Rollback order: the generation first, then the gated role re-run.
- Each child Issue covers one role or the named group, with its own blast
  radius and rollback story.

## Related

- [[provision]], [[auto-apply]], [[borgmatic]], [[forgejo-runner]]
