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
  `curl`/`wget` may write to a file but never pipe. `stdenv`'s `runHook` is
  not allowed: it would execute hook scripts from the input packages.

Anything else — `make`, `npx`, `npm ci` without `--ignore-scripts`,
`pip install`, interpreters, `curl ... | sh`, a `builder` that is a script —
is a violation. **No exception list** (Erich's decision on eblume/blumeops#1809):
a new allowlist entry is a consent-gated change to this aspect.

**Scope.** `APPLIES_TO = ["eblume/blumeops"]`; every `*.nix` in the repo is
scanned, including `containers/*/` and the flakes. A FOD is an attrset that
sets `outputHash*` or `fixedOutput = true`, or a `runCommand`/`callCommand`
whose attrset does. It is a structural lint (no nix eval in CI): every
string value under a build-phase attribute of a FOD is checked statement by
statement, and `builder` must be `null` or a fetcher primitive. Fetcher
*calls* (`pkgs.fetchurl { ... }`) are not FODs in source — allowed by
definition.

**Coverage caveat.** Only inline string values are checked: a phase string
assembled in a `let` binding (`buildPhase = cmd`) or spliced in from one is
not seen.

**State of main.** The in-tree FODs are exactly the two allowlisted shapes —
`containers/authentik/webui-deps.nix` (`npm ci --ignore-scripts`) and the
`goModules` prefetched-modules derivation in `containers/alloy/default.nix`
(`go mod download`) — so the suite is green on main by construction; the
authentik `python-deps` FOD was migrated off in eblume/blumeops#1813.
