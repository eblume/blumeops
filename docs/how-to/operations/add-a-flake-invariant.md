---
title: Add a Flake Invariant
modified: 2026-10-04
last-reviewed: 2026-10-04
tags:
  - how-to
  - operations
  - ai
---

# Add a Flake Invariant

A flake invariant is an evaluation-time `assertions` / `warnings` entry that
encodes an incident lesson, so a reintroduced config shape fails the
host's flake-check build before it can reach the machine. Pattern origin: the
[eblume/blumeops#1414](https://forge.ops.eblu.me/eblume/blumeops/issues/1414) first batch.

## When to add one

After fixing an incident whose failure was **config-shape** — the config
compiles and evaluates cleanly but misbehaves only at runtime, and the fix
is a fact about how the config must be shaped (never X, always flag Y).
If the lesson only makes sense against a live system (timing, resource
limits, a second machine's state), an assertion is the wrong tool.

## Where invariants live

One module per host flake, named `invariants.nix`, imported from the host's
`configuration.nix`:

- `nixos/ringtail/invariants.nix` — NixOS; `assertions` is a list of
  `{ assertion; message; }` sets.
- `darwin/indri/invariants.nix` — nix-darwin; same set shape for
  `assertions`, plus `warnings` (plain strings, `lib.warnMsg`-style) for
  lessons that are "don't rely on this" rather than "this is broken".

Both are wired into each host's built system attribute, so the existing
flake-check workflows (`.forgejo/workflows/ringtail-flake-check.yaml` and
`.forgejo/workflows/indri-flake-check.yaml`) enforce them at zero extra cost — the guard
fails the same build that would have shipped the bad config.

## Message format

Entries follow a four-part format, so the build failure is its own
postmortem (each part as the lesson allows):

```
<host>: <what is forbidden or required> — <why/lesson>.
Incident <forge link(s)>. To lift: <the deliberate action, including
"remove/relax this entry in the same PR">.
```

## Assertion vs warning

Hard `assertion` when re-introducing the violation breaks a live service
with no self-heal, downgrades security posture, or makes a CI gate lie
green. `warning` when the value is intentional but the lesson is
"don't rely on this" — warnings print at eval and never fail the build, so
the flake-check log carries the lesson without forcing a change.

## Trigger coverage

The flake-check workflows trigger on `nixos/ringtail/**` /
`darwin/indri/**` only. An invariant file lives in its host's flake dir and
reads only that flake's `config`, so the existing path filters cover it.
A future invariant that reads files **outside** the flake dir needs one of:
add the path to the workflow's `paths`, relocate the file into the flake
dir, or promote it to the pattern below.

## Beyond module options

Some invariants are not expressible as host-module assertions: cross-file
checks, the `containers/` flake (no NixOS module), or anything comparing
nix config to `argocd/manifests/`. Those belong in a flake `checks` output
exercised by `nix flake check` (or a mise task) — a separate pattern, not
a stretch goal for `assertions`.

## Worked example

A guard from `darwin/indri/invariants.nix` (#1225, #1363): launchd starts
jobs before `/nix` is mounted at login, so a `/nix/store` argv0 dies
`EX_CONFIG` and is never respawned.

```nix
inStore = p: lib.hasInfix "/nix/store" p;
# launchd takes argv0 from Program when it is set, else ProgramArguments[0].
argv0Of = cfg:
  if cfg.Program != null then cfg.Program
  else if (cfg.ProgramArguments or []) == [] then null
  else builtins.head cfg.ProgramArguments;
# ...
assertions = lib.flatten (lib.mapAttrsToList (n: a: guard "user agent" n a.serviceConfig) userAgents);
```

Note the guard checks the *precedence launchd actually uses*, and the
message names both incidents and how to lift the guard deliberately. The
ringtail file guards absence and flags instead (`services.k3s.manifests`
empty, `--write-kubeconfig-mode=600` present) — same shape, different
predicate.

## Verifying an invariant in the pod

The talos pod can evaluate both flakes (indri is aarch64-darwin, but eval
works; only the build is runner-bound). Each host flake is its own flake
(dir with its own `flake.nix`), so run from there — matching the
workflows:

```sh
cd nixos/ringtail && nix build .#nixosConfigurations.ringtail.config.system.build.toplevel  # the exact CI expression
cd darwin/indri   && nix eval --impure .#darwinConfigurations.indri.system.drvPath
```

Prove both halves: the positive (clean on main) and a negative — a scratch
module, *not committed*, that violates the guard and fails with the
intended message.

## Second-batch candidates (not yet invariants)

From the #1414 survey — verify each against the current config before
promoting:

- oomd scoping: `enableUserSlices` on / `enableRootSlice` off on ringtail —
  k3s pods must never be pressure-kill candidates.
- `nix.enable = false` pin on indri (Determinate owns Nix there).
- The `mcquack.eblume.*` launchd agent-label prefix (namespace discipline).
- colima profile-and-template double declaration (#1383).

## See also

- [eblume/blumeops#1414](https://forge.ops.eblu.me/eblume/blumeops/issues/1414) — the pattern issue
- [eblume/blumeops#1426](https://forge.ops.eblu.me/eblume/blumeops/pulls/1426) — ringtail's `invariants.nix`
- [eblume/blumeops#1429](https://forge.ops.eblu.me/eblume/blumeops/pulls/1429) — indri's `invariants.nix`
