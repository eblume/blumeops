# instance-config-out-of-components

Invariant: no instance values — `eblu.me` hostnames, the owner name
`eblume`, and 1Password `op://` references — in the component source of the
target repos, including prompt strings. Component source is the `src/`,
`prompts/`, and `app/` trees as they exist: talos ships `src/`+`prompts/`,
horkos ships `app/`. Every hit is a hard-coded instance assumption that
would otherwise ship to production.

**Scope.** `APPLIES_TO = ["eblume/talos", "eblume/horkos"]`: the check
scans those repos' component dirs, so the fixture trees under
`aspects/` are never scanned. Exemptions (code files only — non-code
files under `prompts/` and similar are scanned verbatim): full-line
comments, docstrings and JSDoc blocks, and test files. The scanner is
line-oriented, not a parser: a multi-line string *value* that opens at
the start of a line can be misread as a docstring and exempted; the
per-repo linters remain the backstop until they are retired. Both repos
already ship per-repo linters (talos `scripts/instance-refs.ts`, horkos
`scripts/instance-refs.py`) with the same prose-exempt policy, and this
aspect consolidates that policy durably; deleting those per-repo scripts
(talos#318) is a separate change.

Alternatives rejected: (a) per-language AST linters — duplicated,
per-language logic for a policy that is really "these literals never
ship"; (b) whole-repo scan — nix files and workflows are legitimately
instance configuration; (c) banning bare node names (ringtail/indri/
gilbert) — ordinary English words, false-positive noise in fixtures; (d)
banning the repo name `blumeops` — horkos's publisher legitimately
constructs the instance image-repo path from it; a known gap for a
future tightening.
