---
title: Eval-based FOD check
modified: 2026-10-26
last-reviewed: 2026-10-26
tags:
  - explanation
  - ai
  - design
  - security
---

# Eval-based FOD check

The eval-based check behind the `fod-only-downloads` invariant —
**nothing downloaded executes inside a FOD**. The static scanner
([eblume/blumeops#1849](https://forge.ops.eblu.me/eblume/blumeops/pulls/1849))
stays as the fast per-PR pre-check; this check is the invariant. Filed:
[blumeops#1860](https://forge.ops.eblu.me/eblume/blumeops/issues/1860).
Decision record: the [2026-10-23 design change on the #1809 thread](https://forge.ops.eblu.me/eblume/blumeops/issues/1809#issuecomment-31295)
— after four review rounds of the static scan, each finding holes of the
same kind, the invariant moves from source-shapes to evaluated shapes.

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

The check must eval with network fetches. It runs on `indri-build`, which is
credential-free and must stay so; `nix-container-builder` is the fallback
(it holds credentials the check never needs). Whatever runner it lands on,
it runs credential-free: `GITHUB_TOKEN` blank, `persist-credentials: false`
on checkout, no `secrets.*` — the same shape as the Aspects job, because
checkout persists the default token into `.git/config` before any step
evaluates repo Nix.

Measured facts behind the choice:

- **Both runners permit eval-time network fetches** (fetchurl to a public
  host and fetchGit to the forge mirror). The constraint on the runner is
  privilege, not network.
- **Platform pin.** The container entries are evaluated for `x86_64-linux`
  whatever the runner's platform. On the darwin runner six containers do not
  instantiate (three darwin-specific, plus three shared failures), and the
  closures differ between platforms, so the pin keeps the result stable and
  matches what is deployed. On `indri-build` this is a cross-system eval;
  eval and the derivation walk build nothing, so the cross-system eval should hold.
- **Cost.** Full-tree is minutes: the container loop is 95 s on
  nix-container-builder and 142 s on indri-build (per-container walks 0–2 s);
  the ringtail host flake is 19 s eval + 6 s walk on nix-container-builder
  and 84 s + 4 s on indri-build. The ringtail closure is identical on both
  runners (12228 drvs / 4885 FODs) — its flake is pinned to x86_64-linux.
- **Ringtail flake purity.** The ringtail eval is pure, without `--impure`
  and with IFD off: `nixos/ringtail/configuration.nix` imports
  `../../forge/runners.nix` (and `../../ntfy/topics.nix`) relative to the
  flake root, so evaluated from a git checkout the whole repo is the flake
  source. The check therefore evals the ringtail flake from a git flake ref,
  never a `path:` copy of the subdirectory — a bare copy resolves `../..` to
  `/nix` and fails.

## Gates

- **Nightly** (`fod-eval-check.yaml`, `schedule`, 03:20 UTC) runs the full
  tree on `indri-build`. A red nightly files one issue, or comments on the
  open one, with the per-run token (no ntfy).
- **On PRs touching Nix or the check's inputs** (`**/*.nix`,
  `**/flake.lock`, `containers/**`, `nixos/ringtail/**`, `forge/runners.*`,
  `ntfy/topics.*`, `pulumi/{tailscale,gandi}/**`, `mise.toml`,
  `mise-tasks/fod-eval-check`, `fod-eval-check/**`, and the workflow itself) — the full tree, as a
  standalone job (about 4 min on indri-build).
- **Not named in `forge/branch-protections.json`.** The path filter means a
  PR that touches no Nix posts no context, and a named required context
  would block it forever. The `* (pull_request)` glob blocks on a failure of
  this job when it does run, the same as the flake checks.
- **The self-test is scoped.** On a PR, the `FOD check self-test` step runs only when the diff from the fork point touches `fod-eval-check/**`, `mise-tasks/fod-eval-check` or the workflow file; a Nix-only PR runs just the full-tree walk. Nightly and dispatch always run both, and any scoping error runs the self-test.

## Relationship to the static pre-check (#1849)

The static scanner remains the fast per-PR signal and is documented as a
pre-check, not the invariant. Where the two disagree, the eval-based result
is authoritative: the static scan may flag a FOD the eval walk classifies
(the eval check is what matters), and may miss shapes the eval walk
catches (this is the invariant).

## Catalogue of hand-written FODs

Closed by enumeration; the catalogue (`fod-eval-check/catalogue`) is the
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

## Related

- [[aspects]] — the suite this check informs. The check runs as a standalone
  job, not an `aspects/` package, because the 10 s/test + 120 s/repo contract
  can't hold a full-tree eval.
- [eblume/blumeops#1849](https://forge.ops.eblu.me/eblume/blumeops/pulls/1849) — the static per-PR pre-check.
- [blumeops#1809](https://forge.ops.eblu.me/eblume/blumeops/issues/1809) — the design change (comment 31295) that moved the invariant to evaluated shapes.
- [blumeops#1860](https://forge.ops.eblu.me/eblume/blumeops/issues/1860) — the issue this work is filed under.
