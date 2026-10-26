# Eval-based FOD check

The invariant: **nothing downloaded executes inside a FOD**. This directory
implements the eval-based check behind the `fod-only-downloads` invariant
([docs/explanation/talos-v0.5/fod-eval-check.md](../../docs/explanation/talos-v0.5/fod-eval-check.md),
the contract this code implements; blumeops#1860). The static per-PR
pre-check ([aspects/fod-only-downloads](../../aspects/fod-only-downloads),
blumeops#1849) stays as the fast source-scan; this check is the invariant,
read from the evaluated derivation graph.

```
fod-eval-check/
  check.py          # the CLI: nix orchestration only — instantiate, walk, report
  classify.py       # the core: pure over JSON — family classification, hook rule
                    #   (the canonical template instances live in check.py's
                    #   `_TEMPLATE_EXPR`, evaluated per nixpkgs source)
  catalogue/         # the hand-written FODs (closed list, post-#1852), per pname
  fixtures/          # red/ (must be rejected) and green/ (must be accepted)
  test_check.py      # the fixture meta-tests + the trust-anchor unit tests
```

Run: `mise run fod-eval-check [--repo DIR] [--flake-src REF] [--store PATH]`.
The mise task's PEP 723 script pins `pytest==9.1.1` (lockstep with the
aspects task). `mise run fod-eval-check -- --self-test` runs the fixture
meta-tests instead of the full tree (nix evals only).

## The check

For every entry point:

1. **Instantiate.**

   - every `containers/*/default.nix` (glob, so a new container can't be
     skipped) with `nix-instantiate --system x86_64-linux` and
     `--option allow-import-from-derivation false`. The system pin is the
     deployment target, so the result is platform-stable on any runner
     (`--system` overrides `builtins.currentSystem`; verified in-pod that a
     cross-system instantiation produces the x86_64-linux packages).
   - the ringtail flake's toplevel:
     `nixosConfigurations.ringtail.config.system.build.toplevel.drvPath`,
     a pure `nix eval` with IFD off, from the checkout's plain relative
     path ref (`./nixos/ringtail`) exactly as the runner spike used it.
     (The darwin/indri toplevel is out of scope; see "Scope" below.)
     `--flake-src git+file:///abs` switches to explicit git refs for
     in-pod verification (the worktree is not libgit2-readable).

   An instantiation/eval error — including an import-from-derivation, which
   the disabled option turns into an eval error — is recorded and the entry
   point is **red** (fail closed).

2. **Walk.** `nix derivation show -r` over the result (with
   `--extra-experimental-features 'nix-command impure-derivations
   ca-derivations'` so an unhashed impure output serialises as
   `outputs.*.impure: true`; harmless otherwise). A walk failure is red.

3. **Select the fixed-output/impure derivations.** `outputs.*.hash != null`
   (a hashed network fetch) or `outputs.*.impure == true` (an unhashed one).
   There is no top-level `outputHash`/`__impure` key in the serialisation
   (`nix derivation show` decides FOD-ness solely in the outputs map).

4. **Classify** each against the known shapes (below), matched against
   template instances evaluated from the **same nixpkgs source** the entry
   point uses.

5. **Inspect setup hooks** (the hook rule, below).

6. **Fail closed.** Anything unrecognised — and evaluation errors themselves
   — is a violation. No exception list; a new builder/hook means extending the
   known shapes first. Exit 0 iff zero violations *and* zero eval errors.

## Trust anchor

Every nixpkgs source used as a template is authenticated by its **locked
identity** before anything is evaluated — a re-pointed template source is a
"cannot classify" red, never a silent acceptance:

- **flake inputs** (`nixos/ringtail/flake.lock`, `darwin/indri/flake.lock`):
  for every locked input that is actually *used* as a template source (its
  `legacyPackages.<system>` has a usable `fetchurl` — the same predicate the
  template wrappers use), the lock node's `original` must be
  `github:NixOS/nixpkgs` (or the equivalent `https://github.com/NixOS/nixpkgs`
  / `git+https://github.com/NixOS/nixpkgs` spelling). The flakes' own pkgs
  anchor on their `nixpkgs` input the same way. An input with
  empty/absent `legacyPackages` is not a template source and needs no anchor
  (it falls back to the primary pkgs as before).
- **`containers/flake.lock`** (the 24 `<nixpkgs>` containers and the
  containers context): the locked `nixpkgs` node's identity must be
  `github:NixOS/nixpkgs`.
- **self-pinning containers** (the 7 with a literal `fetchTarball`): the
  strict pattern `https://github.com/NixOS/nixpkgs/archive/<40 hex>.tar.gz`
  *is* the identity check — see “Self-pinned containers and NIX_PATH”.
- **the catalogue**: the catalogue file list is closed in code (`check.py`
  `DECLARED_CATALOGUE`); any file not in the declared set — a PR adding
  `catalogue/evil.json` — or a declared pname without a file fails red.
  Adding an entry means editing the declared set in the same reviewed diff
  (the enumeration PR will do that). The catalogue closure enforces the
  SET, but a catalogue entry's CONTENT is review-trusted: a
  self-consistent container+catalogue change passes exact-match by design
  (the catalogue diff IS the list).

No rev is pinned: any genuine NixOS/nixpkgs pin is acceptable — rev changes
are human-reviewed in the diff. The anchor is on the *identity* of the
source. An anchor failure names the untrusted source in the violation line.

## The known shapes

Each family is recognised by its distinguishing key set and matched
structurally against its template. **The comparison surface is the whole
serialised derivation** — every env + structuredAttrs key, the top-level
`builder`, `args`, `name`, `system`, the `inputs.srcs` builder scripts and
the outputs' `method`/impurity — compared **strict-equal to the matched
template, except the family-declared instance-variable keys** below.
Everything not declared is compared; a derivation that matches no known
shape, or differs from its template anywhere outside the declared instance
vars, is a violation.

### The template bundle

`check.py` evaluates one expression per context containing the canonical
template instances (a fetchurl with a zeroed hash, a fetchgit with a fake
hash, …). Templates live in the **same nixpkgs** as the entry point:

- the 24 `<nixpkgs>` containers: `import <nixpkgs> {}` with
  `NIX_PATH` = the containers lock resolution (`./containers#nixpkgsPath`,
  the build workflow's shape);
- the 7 self-pinning containers (teslamate, paperless, audiobookshelf,
  navidrome, miniflux, mealie, prowler): `import (fetchTarball { url =
  "<extracted>"; sha256 = "<extracted>"; }) {}` — the url+sha256 are
  extracted from `default.nix` by a strict, minimal pattern
  (`fetchTarball { url = "…/archive/<40 hex>.tar.gz"; sha256 = "<52 …>"; }`);
  if the pattern does not match, the container is red ("cannot determine the
  nixpkgs source"), never skipped;
- the ringtail flake: the flake's own config `pkgs`
  **plus every locked flake input's `legacyPackages`** (ringtail's closure
  legitimately mixes nixpkgs-services and nixpkgs-snowflake derivations — the
  design doc's "same nixpkgs source" generalised to sources), **plus the
  multilib variant `pkgs.pkgsi686Linux` of each source**: ringtail is a
  gaming box whose steam/glibc-multi closure contains i686-linux fetches of
  the same sources, with their own stdenv/bash/curl store paths. Inputs
  without a usable complete `legacyPackages.<system>` (or refused on the
  platform) fall back to the flake's own pkgs; the templates are
  de-duplicated per (name, builder, system).

Classifying a walk FOD against a family means *any* of the context's
templates for that family (the fetchpatch + fetchpatch2 shapes, the fetchzip
stripRoot true/false shapes, the vendor **and** proxyVendor goModules
shapes, the per-source/per-system variants).

### The builder

`builder` must equal the matched template's `builder` exactly. A store-path
builder that differs from the template is red, whatever derivation produces
it. This is the rule that closes the foreign-builder holes
(`red/foreign-builder-fetchurl.nix`, `red/builder-from-fod-output.nix`).

The one place a non-template builder is named rather than merely rejected is
the unrecognised-shape fallback: a FOD with no matched shape whose builder is a
downloaded derivation's output, or a path no derivation in the walk produces, is
reported with that reason (`_builder_problem`). The `builtin:fetchurl` builder
is the only accepted non-template value.

### The compared set and the declared instance vars

`args`, `inputs.srcs`, `buildCommand`, the phase attrs, the hook-inheriting
attrs (`propagated*`), `system`, the outputs' `method`/impurity, `preFetch`,
`stdenv`, `mirrorsFile`, `nativeBuildInputs` and `builder` are compared
strictly against the anchored template. `postFetch` is compared strictly on
every family except the allow-listed ones below.

The family-declared instance-variable keys (env/structuredAttrs keys whose
value legitimately varies per instance) are:

| Family | Instance vars (env or structuredAttrs) | Reason every one is per-instance |
| --- | --- | --- |
| fetchurl | `name`, `url`/`urls`, `rev`, `hash`, `outputHash`, `outputHashAlgo`, `outputChecks`, `out`, `patches` | the fetcher call-site parameters; the fixed-output hash's derived forms; the output path. |
| fetchpatch (incl. fetchpatch2) | fetchurl's (no `patches`), `postFetch` (allow-listed) | the patch url/hash/output; the per-patch postFetch, which must be empty or exactly one text in `allowed-postfetch.json` ([eblume/blumeops#1951](https://forge.ops.eblu.me/eblume/blumeops/issues/1951)). |
| fetchzip (fetchTarball is the fetchzip alias in nixpkgs) | fetchurl's + `extension`, `stripRoot`, `pname`, `version`, `downloadToTemp`, `postFetch` (allow-listed) | fetchzip parameters (incl. the darwin SDK helper's `downloadToTemp`); the per-package postFetch, which must be empty or exactly one text in `allowed-postfetch.json`. |
| fetchgithub (fetchFromGitHub-over-fetchzip) | fetchzip's + `owner`, `repo`, `rev`, `tag`, `revCustom`, `githubBase` | the fetchFromGitHub parameters. |
| fetchgit (incl. fetchFromGitHub-over-fetchgit) | fetchurl's + `fetchSubmodules`, `deepClone`, `leaveDotGit`, `sparseCheckout`, `sparseCheckoutText`, `owner`, `repo`, `githubBase`, `tag`, `revCustom`, `postFetch` (allow-listed); the wasi-libc cross-build inert args `cmakeFlags`, `configureFlags`, `mesonFlags`, `NIX_CFLAGS_LINK`, `dontDisableStatic`, `strictDeps` | the fetchgit/fetchFromGitHub parameters; the cross-build artefacts of one real-tree instance (inert under the fetchgit builder). `postCheckout` and `NIX_PREFETCH_GIT_CHECKOUT_HOOK` are NOT instance vars: the template value is empty, so a non-empty one is red. |
| fetchhg / fetchsvn | `name`, `url`, `rev`, `subrepoClause`, `hash`-forms, `out` | the fetch parameters. |
| npmDeps | `name`, `src`, `hash`/`outputHash`/`outputChecks`, `out`, `fetcherVersion`/`NPM_FETCHER_VERSION`, `forceGitDeps`, `forceEmptyCache`, `dontInstall`, `NIX_NPM_REGISTRY_OVERRIDES`, `sourceRoot`, `patches`, `patchFlags`, `prePatch`, `postPatch`, `preBuild`, `postBuild` | fetcher params + the package-forwarded args. |
| pnpmDeps | `name`, `src`, `hash`-forms, `out`, `fetcherVersion`, `pnpm`, `version`, `nativeBuildInputs`, `pnpmWorkspaces`, `sourceRoot` | params + the per-instance pnpm/node tool inputs. |
| goModules | `name`, `pname`, `version`, `src`, `hash`/`outputHash`, `out`, `modRoot`, `sourceRoot`/`setSourceRoot`, the GO tool env (`GOOS`, `GOARCH`, `GOFLAGS`, `CGO_ENABLED`, `CGO_CFLAGS`, `GO111MODULE`, `BASH_PATH`, `NIX_MAIN_PROGRAM`), `nativeBuildInputs`, `buildInputs`, `patches`/`patchFlags`, the forwarded run-hooks (`preBuild`…`postFixup`), and the observed buildGoModule passthrough args (`vendorHash`, `proxyVendor`, `deleteVendor`, `tags`, `ldflags`, `subPackages`, …) | buildGoModule threads the whole package arg set through the deps FOD env; the generated phase text (which executes) stays strict. `GOTOOLCHAIN` is NOT an ivar: every instance carries `GOTOOLCHAIN=local`; a toolchain-switching value makes go download an un-hashed toolchain, so it is strictly compared. |
| caddyDeps | `name`, `pname`, `hash`/`outputHash`, `out`, `version` | the caddy version/plugins params (the `--with` list is a phase-text splice). |
| cargoDeps | `name`, `src`, `hash`-forms, `out`, `cargoRoot`, `sourceRoot`, `patches`, `postPatch`, `preBuild`, `postBuild` | the package args (src subtree, lockfile-root) + forwarded run-hooks. |
| yarnDeps | `name`, `yarnLock`, `hash`-forms, `out` | the lockfile + name + hash. |
| nixpkgs-native / catalogue | none | byte-identical to the re-evaluation from the same source+system. |

`SSL_CERT_FILE` is a universal instance var: fetchurl's value is hash-derived
(a fake-hash template keeps TLS verification, a real instance disables it).

`inputs.srcs` tolerates, in the package-FOD families only, the per-instance
source/lockfile and the package-issued patch inputs (store-path data entries),
and for fetchgit the cross stdenv's Meson cross-file. A foreign script is red.

## Boundaries: what this eval check owns, and what it does not

The eval check owns the **executing and downloaded surface** of a FOD: the
fetcher shape, every compared key above, the phase/buildCommand text the
builder executes, and the setup-hook universe.

**Per-package `postFetch` on fetchzip, fetchgithub and fetchgit is an
exact-text allow-list.** Their `postFetch` executes inside the FOD, before the
output hash is verified, so the hash does not cover it. A non-empty value must
exactly equal one `text` in `fod-eval-check/allowed-postfetch.json`; anything
else is a violation. fetchpatch's `postFetch` is on the same list (see
[eblume/blumeops#1951](https://forge.ops.eblu.me/eblume/blumeops/issues/1951)).
Each entry carries a one-line `reason`, and the list is the review record.
fetchurl has no `postFetch` on the list. The fixture
`red/postfetch-exec-fetchzip.nix` is an ordinary red fixture.

Known red findings (not exceptions): the full tree on ringtail reports the
flyctl fetchgit FOD (non-empty `postCheckout`, blumeops#1926) and the authentik
findings (blumeops#1910). These stay red until their follow-ups land; nothing is
accepted by exception.

`fetchurl`'s `preFetch`/`postFetch` are empty in every instance and are
compared exactly. `postCheckout` / `NIX_PREFETCH_GIT_CHECKOUT_HOOK` are compared
exactly (empty in the template).

A toolchain-switching `GOTOOLCHAIN` (anything but `local`) on a goModules
FOD is red by construction.

The static pre-check (`aspects/fod-only-downloads`, `_FETCHER_SHELL_ATTRS`) is
the fast source-scan for shell text in fetcher attrs; it covers the source
side of the same postFetch surface.

### fetchpatch vs fetchurl: one shape, two labels

In this nixpkgs rev the fetchpatch parameters (strip index, relative/dirs,
excludes/includes/hunks, revert) are **consumed into the postFetch TEXT at
eval time** — verified against the closure: fetchurl and fetchpatch
instances share identical key sets and byte-identical
`builder`/`args`/`inputs.srcs`, so **no surviving compared key
discriminates them**; the only difference is the postFetch text (which
fetchpatch allow-lists). The classifier therefore matches
either family's templates for a urls-shaped FOD (the fetchpatch label is
kept for diagnostics, from the postFetch marker). The gn/colima-shaped
fetchgit templates were dropped for the same reason: those packages match
the plain fetchgit template (identical builder/args/inputs.srcs).

### Phase attrs

Exactly the design doc's five — `unpackPhase`, `buildPhase`, `installPhase`,
`fixupPhase`, `postFixupPhase` — plus `patchPhase`, `configurePhase`,
`checkPhase`. An attr present on the derivation must equal the template's
value for the same attr (after the family's normalisation below); a phase
attr the derivation has that the template lacks is red too ("where present"
cuts both ways). The `pre*`/`post*` run-hook attrs are **instance
arguments**, not template text: `buildGoModule` forwards a package's own
`preBuild` into its deps FOD, `buildNpmPackage` forwards
`prePatch`/`postPatch` into its deps FOD. They are declared instance vars
(above); their content is source-visible forwarded package args — the
static pre-check's graded surface.
The family fetcher-parameter splices into the phase text are masked exactly
as `urls` is:

- `npmDeps` — the buildPhase embeds the instance's own `outputHash` SRI as
  the `outputHash="…" prefetch-npm-deps` argument;
- `pnpmDeps` — the installPhase embeds the resolved pnpm version digits
  ("pnpm version 10/11"), the version comparison digits, the workspace
  `--filter=<pkg>` list (and its holder-line indentation), and the
  `.fetcher-version` echo digit;
- `goModules` — the buildPhase embeds the instance's `outputHash` SRI;
- `caddyDeps` — the buildPhase embeds the `--with <plugin>` list.

(No postFetch text normalisation: the allow-listed postFetch is compared by
exact text, fetchpatch's included.)

## The hook rule

A derivation *provides a setup hook* iff its effective `buildCommand` (env
or structuredAttrs) installs `$out/nix-support/setup-hook` — the nixpkgs
setup.sh contract; the design doc's "has a `setupHook` output" predicate does
not exist in this nixpkgs rev (makeSetupHook products have a plain `out`
output), this marker is the documented replacement.

A FOD's *effective hooks* are the hook-providing derivations linked to it
through hook-providing drvs: its direct hook inputs, plus the hooks those
hooks depend on, transitively (a hook that itself inputs — or
`propagatedNativeBuildInputs`-deps — another hook-providing drv is in the
effective set). The **allowed universe** for a walk is the hook providers
reachable — through the full input graph — from the **template-side seeds
only**:

- the derivations of the context's template bundle for this entry point
  (the goModules/pnpm templates legitimately carry make-wrapper /
  writable-tmpdir hooks), and
- the stdenv-family derivations of the context's template sources (the
  stdenv drvs the templates reference; their bootstrap chains hold
  install-shell-files, make-shell-wrapper-hook, writable-tmpdir-as-home-hook,
  …; verified against the real closures that every hook the tree's FODs
  reference is template-side-reachable).

The old walk-wide clause — hooks referenced by ANY non-FOD derivation of the
walk — is **gone**: planting `evil-hook = makeSetupHook`, adding it to an
ordinary package's nativeBuildInputs, and referencing it from a FOD is red
(fixtures `red/foreign-hook-fod.nix`,
`red/foreign-hook-shared-with-normal-drv.nix`), and the transitive rule
catches a hook whose own dependency chain reaches a planted hook (fixture
`red/transitive-foreign-hook.nix`).

A hook whose SCRIPT TEXT sources a foreign hook without a corresponding
input edge is outside the eval check — script text is source content,
graded by the static pre-check's shell-attr surface
(`_FETCHER_SHELL_ATTRS`) plus PR review; input-edge transitivity (the
part this check owns) is what `red/transitive-foreign-hook.nix` pins.

For each hook encountered, the report line names the hook derivation read
from walk JSON — never realised, never built.

## Self-pinned containers and NIX_PATH

The 24 `<nixpkgs>` containers resolve `<nixpkgs>` from
`containers/flake.lock` (the build workflow's pin). The 7 self-pinned
containers ignore NIX_PATH (their `fetchTarball` is extracted, above) —
including on the darwin runner, where the check instantiates them for
x86_64-linux like everything else. A `containers/*/default.nix` that uses
`fetchTarball` but does not match the strict nixpkgs pattern is a red entry
point ("cannot determine the nixpkgs source") — it is never silently
re-contexted under `<nixpkgs>`.

## Scope

In scope: the ringtail flake's toplevel and every `containers/*/default.nix`.
**Out of scope: the darwin/indri flake** (`darwinConfigurations.indri`). The
check does not instantiate it, so its fixed-output derivations are not
classified and its 1,940 FODs are not part of the invariant's verdict. This
is not an exception list: darwin
returns as an entry point only by a deliberate PR that adds it back here and
extends the templates to its per-platform keys.

## The system pin

`x86_64-linux` (`--system` on every container instantiation and container
template evaluation). The ringtail flake declares x86_64-linux; the check
runs un-pinned for the host flake (its flake-declared system drives the
eval). The multilib `pkgsi686Linux` variants are evaluated only for the
x86_64 host flake (ringtail); the containers have no i686 FODs.

## Fixtures

`fixtures/red/*.nix` must each evaluate to a derivation whose walk is
rejected; `fixtures/green/*.nix` to one whose walk is clean. The harness
instantiates each fixture (pinned nixpkgs, IFD off, system pinned) with the
container-context templates and the catalogue, and asserts the outcome —
plus a hard error if `fixtures/red/` is empty (a guard that can't fail can't
be added). Each red fixture's comment names the mechanism it pins:

- the builder holes: `red/builder-from-fod-output.nix` (a FOD whose
  builder is the output of a fetchurl — "builder is a downloaded
  derivation"), `red/foreign-builder-fod.nix` (a foreign non-bash store
  binary builder on an unrecognised shape — red on the SHAPE: a FOD must be
  an intact known fetcher shape);
- the always-compared keys: `red/tampered-buildcommand.nix` (an added
  `buildCommand` on a fetchurl shape), `red/tampered-fetchurl.nix` (an
  added `buildPhase`), `red/custom-buildphase-fod.nix` (a hand-rolled FOD
  with a custom buildPhase), `red/impure-derivation.nix`;
- the hook rule: `red/propagated-hook-fod.nix` (a non-empty
  `propagatedNativeBuildInputs`), `red/foreign-hook-fod.nix`,
  `red/foreign-hook-shared-with-normal-drv.nix`,
  `red/transitive-foreign-hook.nix`.

- the bypass fixtures pinned by the strict comparison: `red/postfetch-exec.nix`
  (executing postFetch on fetchurl), `red/postcheckout-exec.nix` (fetchgit),
  `red/repo-stdenv.nix` (stdenv), `red/fake-curl.nix` (nativeBuildInputs),
  `red/foreign-builder-fetchurl.nix` (builder);
- the per-package postFetch on fetchzip/fetchgithub/fetchgit:
  `red/postfetch-exec-fetchzip.nix` (an unlisted text is a violation).

The green fixtures cover each family + a plain closure; a darwin stage0
green fixture is NOT added: the harness classifies fixtures with the
container-context templates, which cannot carry the darwin per-platform
keys (so a stage0 instance would red on those under the container context) —
the darwin stage0 class is out of scope with darwin (see Scope).

## Known deviations from the design doc (all recorded)

- `config.pkgs` → the flake's top-level `pkgs` (nixosSystem has no
  `config.pkgs` attr).
- "has a `setupHook` output" → the `$out/nix-support/setup-hook`
  buildCommand marker (no such output exists in this nixpkgs).
- "builder equal to the template" is strict: any store-path builder that
  differs from the matched template is red.
- The known shapes are extended to the shapes the real closures contain —
  fetchhg, fetchsvn, fetchpatch(+fetchpatch2), fetchFromGitHub (zip and
  fetchgit shapes), the cargo vendor-staging FOD, fetchYarnDeps, the
  goModules proxyVendor variant, and the nixpkgs-native package FODs.
- The hook universe is template-side reachable only: hooks referenced by
  ordinary (non-FOD) derivations of the walk are not admitted.

## Verification, in-pod

The self-test needs no store override: when the default store is not writable
(a landlocked talos pod), the harness uses a local store under
`$XDG_CACHE_HOME/fod-eval-check-store` (gitignored). CI uses the default store.
Resolution order: `--store PATH` (or `FOD_EVAL_CHECK_STORE`), then the default
store when usable, then the auto local store.

```
cd <checkout>
export HOME=$PWD XDG_CACHE_HOME=$PWD/.cache
uv run --script mise-tasks/fod-eval-check --self-test      # all passed

uv run --script mise-tasks/fod-eval-check --flake-src git+file://$PWD \
    --store $PWD/.cache/fod-eval-check-store                # the full tree
```

The full tree on the current head: see the PR body's Verification section for
the counts and the exact violation list.
