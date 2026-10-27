---
title: Aspect suite
modified: 2026-10-26
last-reviewed: 2026-10-26
tags:
  - explanation
  - ai
  - design
  - testing
---

# Aspect suite

An **aspect test** enforces a durable, project-level property of this
instance (a rule that spans repos or workflows), and runs before merge with
no agent and no human. A plan names the test that proves the work, and work
that establishes a durable property proposes a new aspect.

Where a single repo's own test framework can express a property, the test
goes there. The aspect suite is for properties no single repo's suite can
see. Its contents are instance data and live here, in blumeops, because the
rules are rules *of this instance* and blumeops spans every repo it hosts.

## Layout

```
aspects/<slug>/
  ASPECT.md        intent (2–5 sentences), alternatives rejected, scope filters
  test_*.py        the check: a pytest module
  rules/*.yml      optional matcher rules the test drives (semgrep, ast-grep)
  fixtures/red/    input the aspect must reject
  fixtures/green/  input the aspect must accept
  baseline.json    ratchet aspects only: violations allowed to remain
```

- **Runner: pytest.** It supplies parametrization (aspects × repos),
  selection and JUnit output. The test body is whatever fits the property: a
  semgrep or ast-grep rule, a config parse, `nix eval`, a headless browser
  over a static build.
- **Red-fixture meta-test.** A meta-test fails any aspect without a red
  fixture that its own check actually rejects. A guard that can't fail
  can't be added.
- **Two kinds.** An *invariant* allows zero violations in scope. A
  *ratchet* lists existing violations in `baseline.json`; the list may only
  shrink — a new violation fails, and a removed one leaves a stale entry
  that fails until the baseline is lowered in the same diff.
- **Scope.** Every aspect applies to all managed repos by default. An aspect
  narrows itself in `ASPECT.md` with path globs and/or repo include/exclude
  filters (the repo filter is `APPLIES_TO` on the check module; path scoping
  lives in the check).
- **Quick and side-effect-free.** Reads are fine, even over the network. A
  test never mutates distributed state (no forge posts, pushes, ntfy,
  cluster or registry writes) and is never integration-sized. Budgets: about
  10 s per test and 2 min per repo for the whole suite; over budget fails.

**Runner contract.** Each `aspects/<slug>/` is a Python package
(`__init__.py`); exactly one `test_*.py` module in it exposes `KIND`
(`invariant` | `ratchet`), `check(root) -> list[str]`, and optional
`APPLIES_TO` (an `owner/name` list; absent = every repo). Ratchets carry
`baseline.json`, a JSON string list. Fixtures: each immediate subdirectory of
`fixtures/red|green/` is one case whose directory is passed to `check()`.
`mise run aspects [--repo PATH] [--repo-name OWNER/NAME]` runs the suite;
the Aspects PR job (`.forgejo/workflows/aspects.yaml`, `indri-build`) is
required by name on main, and budgets are enforced — 10 s/test via
pytest-timeout, 120 s wall clock per repo run.

## Changing an aspect needs consent

Adding, weakening or deleting an aspect's rules, filters or baseline (other
than shrinking a baseline) is consent-touching: it needs the owner's go on
the plan. A failing aspect on a PR is a red check like any other; it never
starts a session that edits the aspect to make it pass. A new aspect whose
check needs more than a few structural rules (say, over 50 lines of custom
code) says why in its plan.

## Pilots

| Aspect | Kind | Shape |
|---|---|---|
| `no-new-ansible` | ratchet | Counts *new* files under `ansible/` — playbook, role, template, handler, default, var or files/ content. Edits to existing files pass, so a change to an existing role isn't blocked. |
| `instance-config-out-of-components` | invariant | Line scan of the component dirs (talos `src/`+`prompts/`, horkos `app/`), including prompt strings (TS template literals; py docstrings exempt), for instance values: `eblu.me` hostnames, the tailnet hostname, the owner name, 1Password `op://` refs; comments (whole-line and trailing), docstrings and test files exempt. A narrower complement to the per-repo `scripts/instance-refs` linters (ASPECT.md lists the coverage delta); those linters stay until parity. |
| `fod-only-downloads` | invariant | Fast per-PR structural pre-check for the invariant that nothing downloaded executes in a FOD — the invariant itself is the evaluation-based check in [[fod-eval-check]]; this lints every `*.nix`: a FOD (an attrset with `outputHash*`/`fixedOutput = true`, a `runCommand` with one, or one a nixpkgs builder creates — `buildGoModule` vendor, npm/pnpm deps fetches, fetcher `postFetch`; `fetchMixDeps` is red) runs only fetcher primitives, the allowlisted no-execute fetch modes (`go mod download` with `GOTOOLCHAIN=local`, `npm ci --ignore-scripts`) and inert plumbing — no exception list (eblume/blumeops#1809). The check is a standalone job, not a suite package. |
| `no-log-only-error-handlers` | ratchet | tree-sitter over horkos Python `except` (talos TypeScript `catch` follows): a handler whose body only logs must re-raise, return, increment a metric or send an ntfy notification ([#1566](https://forge.ops.eblu.me/eblume/blumeops/issues/1566), [horkos#57](https://forge.ops.eblu.me/eblume/horkos/issues/57)). |
| `forge-sources-only` | invariant | Every source fetch in `*.nix` (fetchers, pinned source attrsets, flake `github:`/`git+` inputs, Go module paths in plugin lists, `fetchFromGitHub`/`fetchFromGitLab`) and every `Dockerfile*` (`git clone`, `ADD`, `curl`, `wget`) resolves to a forge-hosted source, a PyPI or nixpkgs rule class, or a reviewed entry in `exceptions.json` tagged `exceptional` or `pending-removal` (eblume/blumeops#1980). |

## Related

- [[declared-state-files]] — the declared-state rule the instance-config aspects enforce
- [[fod-eval-check]] — the evaluation-based invariant behind `fod-only-downloads`
