---
title: Manage Ringtail Lockfile
modified: 2026-09-30
last-reviewed: 2026-09-28
tags:
  - how-to
  - ringtail
  - nix
---

# Manage Ringtail Lockfile

The ringtail NixOS flake lockfile (`nixos/ringtail/flake.lock`) is rolled by the
**Ringtail Flake Update** workflow on a weekly schedule. The workflow performs
the checks no human can do from a diff and posts them against the exact SHA it
verified. My role is to read that table, merge on green, and handle the
exceptions the workflow escalates.

## The scheduled update

The workflow (`.forgejo/workflows/ringtail-flake-update.yaml`, also manually
dispatchable) runs every **Sunday 05:00 UTC** on the `nix-container-builder`
runner. Each run:

1. creates a fresh `auto-update/ringtail-flake-<date>` branch from `main` — the
   workflow never writes to any other branch;
2. updates all root inputs — `nixpkgs`, `home-manager`, `disko` — via native
   `nix flake update`, skipping `nixpkgs-services`, which is deliberately
   pinned by rev (see [[review-services]]);
3. records each tracked branch's head via `git ls-remote` at update time, so a
   branch that moves mid-run cannot cause a false exception;
4. builds the system and extracts the kernel version.

It then runs the check battery (below) read-only against the candidate
lockfile and opens a PR whose diff is **exactly** `nixos/ringtail/flake.lock`,
pinned to the head SHA the battery verified.

## The check battery

The battery is implemented by `nixos/ringtail/flake-lock-check` (checks 1-4 read the lock read-only; the system build and kernel checks are composed by the workflow). It is the hard gate: no check may fail for the PR to be green; check 6 can only flag.

The battery runs in the zero-credential job: its narHash check fetches upstream flakes with nix, and nix can read the process environment, so no credential may coexist with it. The posting job holds the token, runs no nix, and pins the artifact byte-for-byte (SHA-256) to what the battery verified before it names the head SHA.

| # | Check | Catches |
|---|-------|---------|
| 1 | **Scope** — only the expected root inputs (`nixpkgs`, `home-manager`, `disko`) moved; every other node, lock, and `original` field is byte-identical to the parent lock (lock v7, parsed). | Unrelated nodes touched, extra inputs, structural tampering. |
| 2 | **Root-input immutability** — `nixpkgs-services`'s `original.rev` is unchanged, and every root input's `original` (type, owner, repo, ref) is unchanged. | Redirecting an input to a different source, or silently moving the pinned `nixpkgs-services` rev. |
| 3 | **Fast-forward only** — for each moved input, the new rev equals the *recorded* head of its tracked branch, and the old rev is an **ancestor** of the new rev (`merge-base --is-ancestor`). | Force-reset branches, side-branch revs, and revs that are not actually the upstream head — the check no human can do from a diff. |
| 4 | **narHash** — the lock's `narHash` matches a fresh fetch of the new rev. | Fetch divergence and corruption. **Not a provenance claim**: it is self-referential (same nix, same runner as the update) and documents that limit honestly. |
| 5 | **System build** — `.#nixosConfigurations.ringtail.config.system.build.toplevel` builds on the same nix `ringtail-apply` rebuilds with (the same build as the `Ringtail Flake Check` job on PRs). | Locks that do not evaluate or build. |
| 6 | **Kernel unchanged** — the built system's kernel version matches what is currently booted on ringtail. A bump is **flagged, never a failure**: the PR says "kernel bump — plan a reboot" (see [Post-deploy maintenance](#post-deploy-maintenance)). | Silent kernel changes under a lockfile roll. |

The battery posts its results as a PR comment **naming the exact head SHA it
verified**, so a merge means "a workflow defined on `main` vouched for this
SHA" — not "I certified these opaque hashes".

## Merging on green

When the table is all green, I merge the PR. The merge stays human: `main`
protection allows only my account to merge, and the Actions token is not
granted merge rights (a bot entry would be path-unlimited, and a broader
credential would sit in Actions secrets readable by every workflow).

After the merge lands on `main`:

1. **horkos** detects the push that touched `nixos/ringtail/flake.lock` and
   files a `ringtail-rebuild.yaml` **warrant request** bound to the merged SHA
   — request only; nothing dispatches automatically
   ([eblume/horkos#48](https://forge.eblu.me/eblume/horkos/issues/48)).
2. I approve the request in Warrant; `warrant-bot` dispatches
   `ringtail-rebuild` at the merged SHA.
3. I continue with [Post-deploy maintenance](#post-deploy-maintenance).

## Exceptions

If any check fails, the workflow does **not** produce a green PR: the PR is
left open, an issue is filed naming each failing check with its evidence, and
the issue is linked from the PR. That issue is the entry point — I (or a
talos session) work it there. A PR with a red row is not merged, and a human
click never substitutes for a failed check.

The optional future: an inline LLM classifier may triage fuzzy cases (e.g.
whether an upstream changelog is noteworthy) by escalating to a human. The
deterministic battery stays the hard gate; a classifier can escalate, never
approve.

## Why the gate moved

The previous flow ended in a human "review + merge" of a lockfile-only PR.
That review could not actually happen: confirming that a new rev is the real
upstream branch head is not doable by reading a diff of opaque hashes, and
when the lock was generated inside the agent pod no trusted party vouched for
the revs at all. A human gate that only certifies hashes is worse than no
gate — it trains the reviewer to rubber-stamp exactly the diff shape a
malicious change would disguise itself as.

The verification therefore moved into a workflow on a trusted runner, and the
human decision became one a human can actually make: read the check table,
merge. Two constraints shape the design:

- **No secrets in the nix-evaluating job.** Nix evaluation can read
  environment variables (`builtins.getEnv`) and fetch URLs, so the
  update/build job holds no secrets at all. The only job that holds the
  default token runs no nix — it runs the battery and posts results.
- **The PR is pinned.** The diff must be exactly the lockfile, and the posted
  result must name the SHA it verified, so the verified head and the merged
  head cannot diverge.

## Lock New Inputs Only

`mise run provision-ringtail` automatically runs `nix flake lock` in a
nixos/nix container before deploying. This resolves any newly added inputs
without upgrading existing ones. If the lockfile changes, the task stages the
file and exits — commit, push, and re-run.

This is the right behavior for provisioning: configuration changes that add a
new input get locked, but existing inputs stay pinned until explicitly
updated.

## Post-deploy Maintenance

After `ringtail-rebuild` applies the merged SHA (or `provision-ringtail`
completes for a config change), perform these steps.

### Check for Kernel Update

Compare the booted kernel against the one in the current system profile:

```fish
ssh ringtail 'echo "Booted:  $(uname -r)"; echo "Staged:  $(readlink /run/current-system/kernel | grep -oP "linux-\K[^/]+")"'
```

If they differ, a reboot is needed for the new kernel to take effect. Reboot
at a convenient time:

```fish
ssh ringtail 'sudo reboot'
```

> **AI agents:** Do not reboot automatically. Inform the user that a kernel
> update is pending and suggest they reboot when convenient.

### Prune Old Generations and Garbage Collect

Old NixOS system generations accumulate over time. The
`prune-ringtail-generations` task handles pruning and garbage collection
together:

```fish
mise run prune-ringtail-generations            # keep 5 most recent + kernel-safe gen
mise run prune-ringtail-generations --dry-run  # preview only
mise run prune-ringtail-generations --keep 3   # keep fewer generations
```

The task keeps the 5 most recent generations plus the most recent generation
whose kernel matches the currently **booted** kernel — this preserves a
rollback target that won't require a reboot. After pruning, it runs
`nix-collect-garbage` to free unreferenced store paths.

## Related

- [[ringtail]] — Host reference
- [[review-services]] — the deliberately pinned `nixpkgs-services` rev
- [eblume/horkos#48](https://forge.eblu.me/eblume/horkos/issues/48) — horkos files the rebuild request on the merge webhook
