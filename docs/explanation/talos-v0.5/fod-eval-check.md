---
title: Talos v0.5 — eval-based FOD check
modified: 2026-10-26
last-reviewed: 2026-10-24
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
Settled by the spike (dispatched from main after the merge — [run 11564](https://forge.ops.eblu.me/eblume/blumeops/actions/runs/11564), main @ 4e9ed3722; the workflow file was removed once settled — recover it with `git show 89e8f00a87e5:.forgejo/workflows/fod-eval-check-spike.yaml`):

- **Both runners permit eval-time network fetches** (fetchurl to a public host and fetchGit to the forge mirror, rc=0 on both). The #1358 constraint is about privileges, not network — `indri-build` stays the runner (credential-free, as it must be), `nix-container-builder` the fallback.
- **Platform pin.** The spike evaluated the container entries for each runner's own platform: on the darwin runner six containers do not instantiate — three darwin-specific (homepage's fakechroot/proot is not portable to darwin; kiwix-serve and tailscale are unsupported there) plus the three shared failures below and the closures differ (alloy 1588 drvs/656 FODs on darwin vs 2102/694 on linux). The check therefore pins the system to `x86_64-linux` — the deployment target — so the result is platform-stable and matches what is deployed. On indri-build that is a cross-system eval (not tested by the spike): eval and the derivation walk build nothing, so it should hold; PR 2's first run confirms it, and if it doesn't work the check moves to `nix-container-builder`.
- **Cost.** Full-tree is minutes: the container loop is 95 s on nix-container-builder and 142 s on indri-build (per-container walks 0–2 s), the ringtail host flake is 19 s eval + 6 s walk on nix-container-builder and 84 s + 4 s on indri-build. The ringtail closure is identical on both runners (12228 drvs / 4885 FODs) — its flake is pinned to x86_64-linux.
- **Ringtail flake purity.** The spike's ringtail eval succeeded on both runners without `--impure`, with IFD off, because the read is pure: `nixos/ringtail/configuration.nix` imports `../../forge/runners.nix` (and `../../ntfy/topics.nix`) relative to the flake root, and evaluated from a git checkout the whole repo is the flake source. No `/nix/forge/runners.nix` exists on any runner — the earlier `/nix/forge/runners.nix` eval error came from a bare `path:` copy of just `nixos/ringtail`, where `../..` resolves to `/nix` (the comment at `nixos/ringtail/configuration.nix` only warns that such a bare copy fails loudly). The check therefore evals the ringtail flake from a git flake ref, never a `path:` copy of the subdirectory.
- **Known failures on both runners**: authentik's import-from-derivation (uv2nix; [blumeops#1867](https://forge.ops.eblu.me/eblume/blumeops/issues/1867), still open) is the remaining red — the check's first green main requires it landed. The kubectl/transmission version asserts ([blumeops#1865](https://forge.ops.eblu.me/eblume/blumeops/issues/1865)) landed while the spike ran: [blumeops#1868](https://forge.ops.eblu.me/eblume/blumeops/pulls/1868) fixed the asserts and [blumeops#1872](https://forge.ops.eblu.me/eblume/blumeops/pulls/1872) / [blumeops#1873](https://forge.ops.eblu.me/eblume/blumeops/pulls/1873) pinned the images.

## Gates

- **Nightly** (`fod-eval-check.yaml`, `schedule`, 03:20 UTC) runs the full
  tree on `indri-build`. A red nightly files one issue, or comments on the
  open one, with the per-run token (no ntfy), modelled on
  `ringtail-flake-update`'s hard-failure report. Sweep wiring is a one-line
  addition when V5-33 lands (not yet filed).
- **On PRs touching Nix or the check's inputs** (`**/*.nix`,
  `**/flake.lock`, `containers/**`, `nixos/ringtail/**`, `forge/runners.*`,
  `ntfy/topics.*`, `pulumi/{tailscale,gandi}/**`, `mise.toml`,
  `mise-tasks/fod-eval-check`, `fod-eval-check/**`, and the workflow itself) — the full tree, as a
  standalone job, since the spike timings fit (~4 min on indri-build).
- **Not named in `forge/branch-protections.json`.** The path filter means a
  PR that touches no Nix posts no context, and a named required context
  would block it forever. The `* (pull_request)` glob blocks on a failure of
  this job when it does run, the same as the flake checks.

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

- **indri-build cross-system eval for x86_64-linux** — eval and the derivation walk build nothing, so indri-build should evaluate the pinned system cross-system; confirmed by PR 2's first run, and if it doesn't work the check moves to `nix-container-builder`.
- **Catalogue final shape** — closed in the enumeration PR (PR 3 of the
  #1860 plan).
- **authentik IFD** — decided in [the #1860 thread](https://forge.ops.eblu.me/eblume/blumeops/issues/1860#issuecomment-31497):
  pre-generate the uv2nix/pyproject output into checked-in Nix, IFD stays off,
  no allowlist; a prerequisite for the check going green — [blumeops#1867](https://forge.ops.eblu.me/eblume/blumeops/issues/1867).

## Related

- [[aspects]] — the suite this check informs; the eval-based
  check runs as a standalone job (not an `aspects/` package) because the
  10 s/test + 120 s/repo contract can't hold a full-tree eval, and the
  suite stays honest to it.
- [eblume/blumeops#1849](https://forge.ops.eblu.me/eblume/blumeops/pulls/1849) — the static per-PR pre-check.
- [blumeops#1809](https://forge.ops.eblu.me/eblume/blumeops/issues/1809) — the design change (comment 31295) that moved the invariant to evaluated shapes.
- [blumeops#1860](https://forge.ops.eblu.me/eblume/blumeops/issues/1860) — the issue this work is filed under.
