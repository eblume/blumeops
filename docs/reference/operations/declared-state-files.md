---
title: Declared-State Files
modified: 2026-10-13
last-reviewed: 2026-10-13
tags:
  - reference
  - operations
  - gitops
---

# Declared-State Files

The files in this repo that declare state living somewhere else (the forge,
a host, a vault, a cluster), each with the one task that applies it and the
`--check` that catches drift. This is the convention; the table is the
inventory. Add a row when you add a file.

## The convention

- **One file, one owner.** A declared-state file has exactly one task that
  applies it. Other consumers may read it, but only the owner writes the
  live system from it.
- **`--check` is the drift gate.** The owner task has a `--check` mode that
  reads no vault, compares live state against the file, and exits non-zero
  on drift. It runs on the weekly schedule and, where the file is in the
  diff, as a PR check. A check that cannot see is a failure, never a pass
  (`UNKNOWN` counts as red).
- **Apply reads back.** Every mutation is read back and compared, because
  some APIs answer 200 without applying (Forgejo's hook edit, and Tailscale
  SSH on indri returns exit 0 for everything).
- **Metadata only.** A declared-state file names things; it never holds a
  secret value. Secrets are referenced by `op://` path or by on-host file
  path, and the public repo stays clean.
- **Only blumeops names this instance.** [[talos-design|talos]] and
  [[horkos]] carry no config or state specific to this deployment. Anything
  that says `eblume`, `eblu.me`, a vault name or a host name belongs here,
  and reaches them as a mounted file or an environment variable
  (`repos.json` is the model). A default in their code that falls back to
  this instance's hostname counts as instance config and belongs here too.
- **Nix reads JSON.** When a nix configuration consumes the file, write it
  as JSON so `builtins.fromJSON (builtins.readFile ./file.json)` works
  without a converter. YAML is fine when nothing in nix reads it.

## The inventory

| File | Declares | Owner task | Check | Other readers |
|------|----------|------------|-------|---------------|
| `argocd/manifests/talos/repos.json` | which repos the `agents` bot may touch, the pod clone pool, which repos get the forge webhooks | `mise run forge-reconcile` | `forge-reconcile --check` (weekly, PR) | the talos pod entrypoint, via a kustomize ConfigMap |
| `forge/branch-protections.json` | branch protection rules on `main` | `mise run forge-reconcile` | same | none |
| `forge/runners.json` | runner topology: name, host, labels, scope, capacity, unit | `mise run forge-reconcile` | `forge-reconcile --check` | `nixos/ringtail/configuration.nix`, `darwin/indri/configuration.nix` |
| `warrant-policy.yaml` | which workflows are requestable, their class, input schemas, SHA binding | none; it is read at request and dispatch time | `request-run` refuses at request time | `mise run request-run`, [[horkos]] |
| `service-versions.yaml` | per-service review freshness and current version | `mise run service-review` (human, updates the file) | `container-version-check` for container pins | `forge-name-lint`, one ringtail nix pin |
| `mise-tasks/forge-name-lint.allowlist.yaml` | exceptions to the forge-name lint | `mise run forge-name-lint` | the lint itself | none |
| `forge/actions-secrets.json` | the Actions secret *names* per repo | `mise run forge-reconcile` (values half: human-only PUT/DELETE from the in-code 1Password sources) | `forge-reconcile --check` compares names | none |
| `darwin/indri/secrets.json`, `nixos/ringtail/secrets.json` | on-host secret files by path, `op://` source, owner, mode, unit to restart | `mise run seed-secrets` | `seed-secrets --check` (vault-free; the weekly host timer is a follow-on) | the per-host flake invariant (invariants.nix lockstep) |

Planned, filed as issues on 2026-10-12:

| File | Declares | Issue |
|------|----------|-------|
| talos instance document | forge URL, bot login, creator allowlist, horkos and argocd endpoints | eblume/talos#314 |

## What is not a declared-state file

- **ArgoCD manifests** under `argocd/`: ArgoCD itself is the owner and the
  reconciler, and `argocd app diff` is the check. See [[argocd]].
- **The nix configurations** under `darwin/` and `nixos/`: the generation
  switch is the owner, `indri-flake-check` and `ringtail-flake-check` the
  pre-apply checks, `invariants.nix` the guards.
- **Changelog fragments, prek and mise config**: tooling, not state.

## Related

- [[warrant-approval-gated-runs]] for why the policy file is reviewed data
  rather than tribal knowledge.
- [[agents-forgejo-bot]] and [[add-a-freestanding-repo]] for `repos.json` in
  practice.
- [[seed-secrets]] for seating the on-host secret files the per-host
  `secrets.json` manifests declare.
- [[security-model]] for the vault tiers the `op://` references point into.
