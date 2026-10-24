---
title: Talos v0.5 — aspect suite (instance)
modified: 2026-10-23
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
  - testing
---

# Aspect suite (instance)

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

An **aspect test** enforces a durable, project-level property of this
instance (a rule that spans repos or workflows), and runs before merge with
no agent and no human. Talos v0.5 makes it a phase of the issue cycle: a plan
names the test that proves the work, and work that establishes a durable
property proposes a new aspect. The phase is generic (talos
[work-items.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/work-items.md));
the suite's contents are instance data and live here, in blumeops, because
the rules are rules *of this instance* and blumeops spans every repo it hosts.

Where a single repo's own test framework can express a property, the test
goes there. The aspect suite is for properties no single repo's suite can
see.

## Layout (V5-31)

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
  can't be added (v0.5 case 16b).
- **Two kinds.** An *invariant* allows zero violations in scope. A
  *ratchet* lists existing violations in `baseline.json`; the list may only
  shrink — a new violation fails, and a removed one leaves a stale entry
  that fails until the baseline is lowered in the same diff.
- **Scope.** Every aspect applies to all managed repos by default. An aspect
  narrows itself in `ASPECT.md` with path globs and/or repo include/exclude
  filters (the repo filter lands as `APPLIES_TO` on the check module — see the
  runner contract below; path scoping lives in the check). A repo added to
  `repos.json` is covered the night it lands.
- **Quick and side-effect-free.** Reads are fine, even over the network. A
  test never mutates distributed state (no forge posts, pushes, ntfy,
  cluster or registry writes) and is never integration-sized. Budgets: about
  10 s per test and 2 min per repo for the whole suite; over budget fails.

**Runner contract (V5-32, as landed).** Each `aspects/<slug>/` is a Python
package (`__init__.py`); exactly one `test_*.py` module in it exposes `KIND`
(`invariant` | `ratchet`), `check(root) -> list[str]`, and optional
`APPLIES_TO` (an `owner/name` list; absent = every repo). Ratchets carry
`baseline.json`, a JSON string list. Fixtures: each immediate subdirectory of
`fixtures/red|green/` is one case whose directory is passed to `check()`.
`mise run aspects [--repo PATH] [--repo-name OWNER/NAME]` runs the suite;
the Aspects PR job (`.forgejo/workflows/aspects.yaml`, `indri-build`) is
required by name on main, and budgets are enforced — 10 s/test via
pytest-timeout, 120 s wall clock per repo run.

## How it reaches every repo

- **Advisory PR CI** in each managed repo checks out blumeops `aspects/` at
  `main` (never the PR branch) and runs the aspects whose filters match. This
  is a fork run with a read token and no secrets, so it is credential-free.
- **The gate** ([[landing-gate]]) runs the same suite on the candidate. The
  gate always holds a write token and secrets (Forgejo ignores
  `permissions:`); aspect code never uses them. That is enforced by review:
  aspect code lands only through eblume's review in blumeops.
- **Wiring** is placed by `forge-reconcile` from `repos.json` (V5-33), so no
  repo is hand-wired.
- **Nightly sweep** runs every aspect against every managed repo's `main`.
  A violation on main becomes a tally-board finding, not an ask. The tally
  board arrives in Wave 10 (V5-53). **Question for the V5-33 body:** until
  then, the sweep posts to one rolling forge issue in blumeops
  (`aspect sweep: violations on main`, edited in place, never a new issue
  per night), or only feeds a Grafana panel. Lean: the panel, because a
  rolling issue is the kind of thread prose v0.5 is trying to retire.

## Changing an aspect needs consent

Adding, weakening or deleting an aspect's rules, filters or baseline (other
than shrinking a baseline) is consent-touching: it needs eblume's go on the
plan, the same rule talos applies to `verify` steps. A failing aspect on a
talos PR is a red check like any other; it never starts a session that edits
the aspect to make it pass. A new aspect whose check needs more than a few
structural rules (say, over 50 lines of custom code) says why in its plan.

## Pilots (V5-32, Wave 2)

| Aspect | Kind | Shape |
|---|---|---|
| `no-new-ansible` | ratchet | Counts *new* files under `ansible/` — playbook, role, template, handler, default, var or files/ content. Edits to existing files pass, so work like V5-05's borgmatic change isn't blocked. |
| `instance-config-out-of-components` | invariant | Line scan of the component dirs (talos `src/`+`prompts/`, horkos `app/`), including prompt strings (TS template literals; py docstrings exempt), for instance values: `eblu.me` hostnames, the tailnet hostname, the owner name, 1Password `op://` refs; comments (whole-line and trailing), docstrings and test files exempt. A narrower complement to the per-repo `scripts/instance-refs` linters (ASPECT.md lists the coverage delta); those linters stay until parity. |
| `fod-only-downloads` | invariant | Fast per-PR structural pre-check for the invariant that nothing downloaded executes in a FOD — the invariant itself is the evaluation-based check in #1860; this lints every `*.nix`: a FOD (an attrset with `outputHash*`/`fixedOutput = true`, a `runCommand` with one, or one a nixpkgs builder creates — `buildGoModule` vendor, npm/pnpm deps fetches, fetcher `postFetch`; `fetchMixDeps` is red) runs only fetcher primitives, the allowlisted no-execute fetch modes (`go mod download` with `GOTOOLCHAIN=local`, `npm ci --ignore-scripts`) and inert plumbing — no exception list (eblume/blumeops#1809). |

## Next aspects (V5-58, Wave 3)

| Aspect | Kind | Shape |
|---|---|---|
| `no-log-only-error-handlers` | ratchet | semgrep over horkos/talos TypeScript: a catch that only logs must re-raise, alert or return an error (#1566, horkos#57). |
| `every-guard-has-a-red-fixture` | ratchet | Meta-aspect over `prek.toml` and `.forgejo/` in pool repos: each prek hook and CI check has a test showing it fail (#1591). |

## Changelog aspects (V5-93, Wave 5)

| Aspect | Shape |
|---|---|
| Every managed repo has a changelog system | Cross-repo check over `repos.json`: towncrier config + `docs/changelog.d/`, or equivalent |
| Every managed repo's PR CI requires a fragment | Meta-aspect over `.forgejo/`: the fragment check exists and is required |
| Every pool repo carries a `prek.toml` | Cross-repo check, so the agent pod installs hooks there |
| Each `prek.toml` has the pre-push `changelog-fragment` hook, and CI runs prek | Meta-aspect over `prek.toml` / `.forgejo/` |

The opt-out is a `<branch>.skip.md` fragment whose body is a one-line
reason: in the PR diff, writable with read-only access, ignored by
towncrier, and deleted by the release kit with the consumed fragments.

## Candidates (not rowed)

| Aspect | From |
|---|---|
| Every pool repo is wired for CI-failure reporting | case 12; moot once V5-29 lands |
| `service-versions.yaml` agrees with every declared pin, for all service types | the service-review scenario; generalizes `container-version-check` |
| Declared state has one owner: docs never say to change a declared setting in a UI | case 10 (hephaestus#91); checks docs against [[declared-state-files]] |

## Open

- Do `repos.json` entries grow `tags` (language, kind) for filters, or do
  filters probe the repo (e.g. "has `*.nix`")? Lean: path globs first, tags
  only if a real aspect needs them.
- How a plan records "test-driven" so it can be checked (V5-34, Wave 11).

## Related

- [[landing-gate]], [[runners-and-trust]], [[declared-state-files]]
