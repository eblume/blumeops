# fod-only-downloads

Invariant: nothing downloaded executes inside a FOD. A fixed-output
derivation has network access during its build, so fetched code must never
run while it has that network. A FOD may only *download*:

- **Fetcher primitives** — `fetchurl`, `fetchTarball`, `fetchGit`, ...:
  fixed-output by construction, no shell.
- **Allowlisted no-execute fetch modes** — the shell may run only
  `go mod download` and `npm ci --ignore-scripts`, plus *inert plumbing*
  (`cd`, `export`, `mkdir`, `cp`, `mv`, `rm`, `ln`, `chmod`, `tar -x`,
  `find` with inert `-exec` subcommands, `echo`/`printf` redirects, ...).
  `curl`/`wget` may only download: every segment of a pipe is checked
  against the same allowlist, so `curl ... | sh` is red. The plumbing
  tools' own exec escapes are rejected: `tar --to-command` / `-I` /
  `--use-compress-program` / `-F` / `--info-script` / `--new-volume-script`
  / `--rsh-command` / `--checkpoint*`, `sort --compress-program`, and a
  `find -exec` subcommand is graded as a full command (not just its name).

`go mod download` is allowed only with `GOTOOLCHAIN=local` — set by a real
assignment (`GOTOOLCHAIN=local`) or `export` statement earlier in the same
phase (a later assignment wins), or prefixed on the command itself. A
mention in a comment or command argument does not set it. With the default
`auto`, a `toolchain` line in a downloaded `go.mod` makes `go` fetch and
*execute* a different Go toolchain inside the FOD.

The check is fail-closed. Anything else is a violation: `make`, `npx`,
`npm ci` without `--ignore-scripts`, `pip install`, interpreters, shell
control flow (`if`/`case`/`for`/`while` — write FOD phases as flat
statement lists), other builtins (`set`, `umask`), command substitution
(`$(...)`, backticks — it would execute the substituted command), a
`builder` that is a script. **No exception list** (Erich's decision on
eblume/blumeops#1809): a new allowlist entry is a consent-gated change to
this aspect.

**Scope.** `APPLIES_TO = ["eblume/blumeops"]`; every `*.nix` in the repo is
scanned, including `containers/*/` and the flakes. Two FOD shapes are
graded:

1. **FODs in source** — an attrset that is passed to a derivation and
   assigns `outputHash*` or `fixedOutput = true` (directly or via
   `inherit`), or a
   `runCommand`/`callCommand`/`execBuilder` (and the `runCommandCC`,
   `runCommandLocal`, `runCommandNoCC` variants) whose attrset does —
   including the lambda forms (`mkDerivation (finalAttrs: { ... })`,
   `drv.overrideAttrs (o: { ... })`). An attrset nested as an attr value
   (`args = { outputHash = ...; }`) is data, not a FOD. The check is
   fail-closed over names and values:
   - every attr except a short allowlist of attrs that hold inert strings
     (`pname`, `version`, `outputHash*`, `sourceRoot`, `vendorHash`, ...)
     is graded;
   - a value that is a lone string literal is checked statement by
     statement;
   - a value that assembles a script from anything else — a let-bound
     identifier (`buildPhase = cmd`), a concatenation, a function call
     (`lib.optionalString ...`), an `inherit` of the attr — is red with
     "inline the phase so it can be graded";
   - a value that is pure Nix data — a number, `true`/`false`/`null`, a
     list, an attrset, a dotted reference (`pkgs.pnpm_10`) — is not shell
     and is green;
   - `builder` must be `null` or a fetcher primitive;
   - a string element of a `phases` / `*Phases` list is an inline phase
     body and is checked too (bare phase names are not);
   - `nativeBuildInputs` is graded by the setup-hook rule below.

2. **FODs nixpkgs builders create** — the call is not a FOD in source
   (no `outputHash`), but the builder derives one internally. The call in
   plain attrset form and the `(finalAttrs: { ... })` lambda form (the
   current nixpkgs idiom, including after a `.override { ... }`) are both
   seen. Verified against `pkgs/build-support/go/module.nix` and
   `pkgs/build-support/node/{build-npm-package,prefetch-npm-deps,fetch-pnpm-deps}`
   at the ringtail nixpkgs rev (see `nixos/ringtail/flake.lock`); re-verify
   when the pin moves:
   - `buildGoModule { ... }` with `vendorHash != null`: the vendor FOD
     inherits `preUnpack`/`postUnpack`/`unpackCmd`, `prePatch`/`postPatch`,
     `preConfigure`/`postConfigure`, `preBuild`, `modPostBuild`,
     `preInstall`/`postInstall`; its phases are `mod*Phase`; and
     `overrideModAttrs` is applied on top — an override wins for a shared
     attr (so `overrideModAttrs.preBuild = "";` clears the inherited hook
     out of the FOD), and any other override becomes a FOD attr. The
     inherited attrs and overrides are graded by the same value rule as a
     plain FOD. The call's `nativeBuildInputs` are graded by the
     setup-hook rule. `vendorHash = null` means no FOD.
   - `buildNpmPackage { ... }`: the deps FOD inherits `prePatch`/
     `postPatch` (and `prePnpmInstall` where pnpm deps are used) — graded
     by the same value rule.
   - `fetchPnpmDeps { ... }` / `fetchNpmDeps { ... }`: the call's attrs
     are spliced into the FOD wholesale — checked like a plain FOD.
   - Any fetcher call: only `preFetch`/`postFetch` run shell in the FOD,
     and they are checked (value rule included).
   - `fetchMixDeps`: any call is red — it has no no-execute mode.

**Setup-hook rule.** A FOD's setup hooks do fire, so a FOD's
`nativeBuildInputs` (and a `buildGoModule` vendor FOD's) are graded, with
no exception list:

- plain nixpkgs package references are inert — `pkgs.foo`,
  `pkgs.go_1_26`, and bare names in `with pkgs; [ ... ]` are nix-built,
  not downloaded;
- anything else is red (a `makeSetupHook` call, a let-bound hook, a local
  import, an unresolvable name), *unless* it resolves to a local
  `makeSetupHook` file whose script registers its hooks only under
  `if [ -z ${outputHash-} ]` — exactly the
  `containers/authentik/api-go-vendor-hook.nix` shape, which passes on its
  merits, not its name. A hook script that also registers outside the
  guard is red.

**Coverage caveat.** List-valued attrs (`patches`, `ldflags`,
`pnpmInstallFlags`, ...) are not seen; a builder reached through a `let`
alias is recognized only when the binding is a direct reference —
`name = pkgs.buildGoModule.override { ... };` — not a wrapper function; a
nixpkgs builder not modelled above (`buildRustPackage`/`fetchCargoVendor`,
`fetchYarnDeps`, gradle/maven deps fetches) is not seen — a new builder
needs this aspect extended before it is used.

**State of main.** The in-tree FODs are exactly the allowlisted shapes:
the plain-FOD ones are `containers/authentik/webui-deps.nix`
(`npm ci --ignore-scripts`) and the `goModules` derivation in
`containers/alloy/default.nix` (`go mod download` with
`GOTOOLCHAIN=local`), plus the builder FODs — the nine `buildGoModule`
vendor FODs (ntfy/prometheus/authentik-server keep their build hooks out
of it via `overrideModAttrs`, per eblume/blumeops#1850), the two
`buildNpmPackage` and two `fetchPnpmDeps` deps fetches (plus teslamate's
`fetchNpmDeps`), all with no FOD-running hooks, and no `fetchMixDeps`
(teslamate's retired in eblume/blumeops#1852) — so the suite is green on main with no exception
list; the authentik `python-deps` FOD was migrated off in
eblume/blumeops#1813.
