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
   `runCommandLocal`, `runCommandNoCC` variants) whose attrset does. An
   attrset nested as an attr value (`args = { outputHash = ...; }`) is
   data, not a FOD. The
   check is fail-closed over names: every attr whose value is a direct
   string literal is checked statement by statement, except a short
   allowlist of attrs that hold inert strings (`pname`, `version`,
   `outputHash*`, `sourceRoot`, `vendorHash`, ...). `builder` must be
   `null` or a fetcher primitive. A string element of a `phases` /
   `*Phases` list is an inline phase body and is checked too (bare phase
   names are not).

2. **FODs nixpkgs builders create** — the call is not a FOD in source
   (no `outputHash`), but the builder derives one internally. Verified
   against `pkgs/build-support/go/module.nix` and
   `pkgs/build-support/node/{build-npm-package,prefetch-npm-deps,fetch-pnpm-deps}`
   at the ringtail nixpkgs rev (see `nixos/ringtail/flake.lock`); re-verify
   when the pin moves:
   - `buildGoModule { ... }` with `vendorHash != null`: the vendor FOD
     inherits `preUnpack`/`postUnpack`/`unpackCmd`, `prePatch`/`postPatch`,
     `preConfigure`/`postConfigure`, `preBuild`, `modPostBuild`,
     `preInstall`/`postInstall`; its phases are `mod*Phase`; and
     `overrideModAttrs` is applied on top — an override wins for a shared
     attr, and any other override becomes a FOD attr. `vendorHash = null`
     means no FOD.
   - `buildNpmPackage { ... }`: the deps FOD inherits `prePatch`/
     `postPatch` (and `prePnpmInstall` where pnpm deps are used).
   - `fetchPnpmDeps { ... }` / `fetchNpmDeps { ... }`: the call's attrs
     are spliced into the FOD wholesale — checked like a plain FOD.
   - Any fetcher call: only `preFetch`/`postFetch` run shell in the FOD,
     and they are checked.
   - `fetchMixDeps`: any call is red — it has no no-execute mode.

**Coverage caveat.** Only inline string values are checked: a phase string
assembled in a `let` binding (`buildPhase = cmd`) or spliced in from one is
not seen; list-valued attrs (`patches`, `ldflags`, `pnpmInstallFlags`, ...)
are not seen; `nativeBuildInputs` setup-hook bodies are not seen (a FOD's
setup hooks do fire — keep a FOD's `nativeBuildInputs` to no-execute
packages, and guard hooks like `api-go-vendor-hook.nix` on
`${outputHash-}` so they register only in the non-FOD build); a builder
reached through a `let` alias is recognized only when the binding is a
direct reference — `name = pkgs.buildGoModule.override { ... };` — not a
wrapper function.

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
