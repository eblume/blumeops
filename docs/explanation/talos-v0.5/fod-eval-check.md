---
title: Talos v0.5 — eval-based FOD check
modified: 2026-10-23
tags:
  - explanation
  - ai
  - design
  - security
---

# Eval-based FOD check (design)

The eval-based check behind the `fod-only-downloads` invariant —
**nothing downloaded executes inside a FOD**. The static scanner
([eblume/blumeops#1849](https://forge.ops.eblu.me/eblume/blumeops/pulls/1849))
stays as the fast per-PR pre-check; this check is the invariant. Filed:
[blumeops#1860](https://forge.ops.eblu.me/eblume/blumeops/issues/1860).
Decision record: the [2026-10-23 design change on the #1809 thread](https://forge.ops.eblu.me/eblume/blumeops/issues/1809#issuecomment-31295)
— after four review rounds of the static scan, each finding holes of the
same kind, the invariant moves from source-shapes to evaluated shapes —
and the #1860 plan.

## Why eval, not scan

Scanning source can't prove the invariant: the escape hatches are
transitive (setup hooks inherited through `nativeBuildInputs`, builders
pulled in by nixpkgs internals, fetchers wrapped in local macros), and each
hole class found in review has another member waiting. The evaluated
derivation graph, by contrast, is closed: everything that will run is named
in it, with its arguments. The `outputHash` attribute marks exactly the
derivations that touch the network — and executing is what the check
forbids, so the walk takes `__impure` derivations too (network without a
hash).

## The check

1. Instantiate every entry point of the blumeops nix trees: every flake
   output of `nixos/ringtail/flake.nix` (nixosConfigurations) and
   `darwin/indri/flake.nix` (the nix-darwin system), plus every
   `containers/*/default.nix`. (`containers/flake.nix` only exports
   `nixpkgsPath`; several containers — teslamate among them — pin their
   own nixpkgs, so the per-container entry points are the unit of
   instantiation.)
2. Walk `nix derivation show -r` over the resulting derivations. The walk
   runs with `--option allow-import-from-derivation false`:
   `nix-instantiate` performs import-from-derivation builds during eval,
   which can run code. With IFD off, an IFD becomes an eval error — red by
   the fail-closed rule.
3. Take every derivation carrying an `outputHash` (a hashed network fetch)
   or an `__impure` attribute (an unhashed one).
4. Match each against the closed set of known-safe shapes:
   - the `fetchurl` family (`fetchurl`, `fetchTarball`, `fetchzip`/
     `fetchzipball`) and the `fetchgit` builders;
   - the nixpkgs `goModules` template (`goModules` / `mkGoModule` deps),
     with no inherited hooks;
   - the npm and pnpm deps fetchers (`buildNpmPackage`'s `npmDepsHash`
     derivation, `fetchPnpmDeps`);
   - the hand-written FODs in the tree (closed catalogue, below).

   The match is structural, read at eval time: compare the derivation's
   evaluated `env` to the corresponding nixpkgs template — `builder` and
   the phase attrs equal to the template, and the inherited-hook attrs
   (`propagatedNativeBuildInputs` and friends) empty. Two shapes need
   explicit allowance: `fetchzip` evaluates to a `fetchurl` *with* an
   unpacking `postFetch` (allowed inside the fetchurl shape), and setup
   hooks are read from the `makeSetupHook` derivation's `env` (the script
   is an input to it) rather than by realising the hook — realising would
   turn the walk into a build and change the runner cost.
5. Inspect the setup hooks of the evaluated inputs: only known nixpkgs
   hooks.
6. **Fail closed.** Anything unrecognised — and evaluation errors themselves
   — fail the check. There is no exception list; a new builder means
   extending the known shapes first. "Informational" only ever means "not a
   required check yet", never "skip".

## Runner

The check must eval with network fetches. Candidate: `indri-build`
(credential-free — preferred, it must stay so; #1358). Fallback:
`nix-container-builder` (it holds credentials the check never needs).
Whatever runner the check lands on, it runs credential-free:
`GITHUB_TOKEN` blank, `persist-credentials: false` on checkout, no
`secrets.*` — the same shape as the Aspects job, because checkout persists
the default token into `.git/config` before any step evaluates repo Nix.
Settled by the spike (`.forgejo/workflows/fod-eval-check-spike.yaml`,
dispatch-only — run it from main after merge, on both runners): does
indri-build permit eval-time network fetches under the unprivileged setup,
and what does full-tree instantiation cost? Verdict: **pending the spike
run** — see the open question below; record it here when it lands.

## Gates

- **Nightly** (V5-33 wave 4; sweep wiring is a one-line addition when the
  sweep lands — V5-33 is not yet filed).
- **On PRs touching `*.nix`**, only if the spike timings fit. If
  full-tree eval is minutes on the chosen runner, the gate narrows to
  `containers/` (the `nixos/ringtail` host flake dominates the cost) or
  stays nightly-only. Gate context name registered in
  `forge/branch-protections.json` when it goes in.

## Relationship to the static pre-check (#1849)

The static scanner remains the fast per-PR signal and is documented as a
pre-check, not the invariant. Where the two disagree, the eval-based result
is authoritative: the static scan may flag a FOD the eval walk classifies
(the eval check is what matters), and may miss shapes the eval walk
catches (this is the invariant).

## Catalogue of hand-written FODs (post-#1852)

Closed by enumeration; the catalogue diff of the enumeration PR *is* the
list:

- `containers/authentik/webui-deps.nix` — npm tree FOD, `webui-deps`;
- `containers/alloy/default.nix` — the hand-written `goModules`
  fixed-output derivation (go modules fetched with `go mod download`).

The rest of the tree's FODs are builder or fetcher FODs, not hand-written
ones: ntfy gets its from `buildNpmPackage`'s `npmDepsHash`, prometheus
its from `fetchPnpmDeps`; teslamate's `beamPackages.fetchHex` entries are plain
derivations over a `fetchurl` — only the `fetchurl` is a FOD, and it is the
fetchurl family; teslamate's FOD is its `fetchNpmDeps`.
`fetchgit`/`fetchurl` source fetches in the other containers (grafana,
mealie, tempo, and the rest) are the fetcher family, not hand-written
catalogue entries.

## Open

- **indri-build eval-with-fetches verdict** — the spike settles it; record
  here.
- **PR-gate budget** — full-tree vs `containers/`-only vs nightly-only.
- **Catalogue final shape** — closed in the enumeration PR (PR 3 of the
  #1860 plan).

## Related

- [[aspects]] — the suite this check informs; the eval-based
  check runs as a standalone job (not an `aspects/` package) because the
  10 s/test + 120 s/repo contract can't hold a full-tree eval, and the
  suite stays honest to it.
- [[explanation/talos-v0.5/waves/wave-4]] — V5-33 nightly sweep this plugs
  into.
- [eblume/blumeops#1849](https://forge.ops.eblu.me/eblume/blumeops/pulls/1849) — the static per-PR pre-check.
- [blumeops#1809](https://forge.ops.eblu.me/eblume/blumeops/issues/1809) — the design change (comment 31295) that moved the invariant to evaluated shapes.
- [blumeops#1860](https://forge.ops.eblu.me/eblume/blumeops/issues/1860) — the issue this work is filed under.
