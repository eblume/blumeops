# every-guard-has-a-red-fixture

Ratchet: every guard must have a red fixture. A guard is a local prek hook
or a PR-gating CI job. Its red fixture is a proof location for a case the
guard must reject, so a guard that cannot fail cannot be added unnoticed.
Tracking: eblume/blumeops#1982.

**Convention.** A guard's red fixture is the directory
`tests/guards/red/<guard-id>/`, holding at least one regular file (searched
recursively). Guard ids:

- a local prek hook: its hook `id`, e.g. `ansible-lint`;
- a PR-gating CI job: `<workflow-stem>.<job-id>`, e.g. `lint.prek`.

**Scope.** In scope are the `repo = "local"` hooks in `prek.toml` and the jobs
of every workflow whose `on:` includes `pull_request`. Out of scope:

- remote and builtin prek hooks (their red tests live upstream);
- jobs of workflows that never run on a pull request (push, schedule,
  dispatch-only): they are not checks on a PR;
- the four named exclusions in `NOT_GUARDS`:
  - `aspects.aspects`: the suite's own job; `aspects/test_meta.py` rejects
    every aspect's red fixture that its check accepts.
  - `build-container.detect`: a classifier that emits outputs for downstream
    jobs and runs no policy; its only failure is an infrastructure error.
  - `build-container.container-test`: a test-runner job; the exporter test
    suites' individual tests are the evidence.
  - `tests.horkos-test`: a test-runner job; the horkos test suite's individual
    tests are the evidence.

Changing `NOT_GUARDS` or the scope rules is consent-touching: see
docs/explanation/aspects.md.

**Violations.** (1) An in-scope guard id with no non-empty
`tests/guards/red/<id>/` is reported by its bare id. (2) An entry directly
under `tests/guards/red/` whose name is not an in-scope guard id (a stale,
renamed or excluded id, or a stray file) is reported as
`orphan red fixture: tests/guards/red/<name>`.

**Known gap.** The check proves that a fixture exists and is non-empty. It
does not run the guard against the fixture. That the guard actually rejects
the fixture is the fixture author's proof; a runner that executes each guard
against its fixture is a follow-up. Existing red tests elsewhere in the repo
(for example forge-reconcile's tests under `tests/`) do not count until they
are migrated to this convention.

**Baseline.** `baseline.json` lists the 24 in-scope guards with no red fixture
at upstream/main: 11 local hooks and 13 PR-gating jobs. It is shrink-only:
adding a fixture removes its entry, and a new guard without one fails the
check.

**Standing cost.** One more aspect in the existing CI `aspects` run: a parse
of `prek.toml` and `.forgejo/workflows`, with no extra job or network.

**Alternatives rejected.** A registry declaring every guard duplicates
`prek.toml` and the workflows, and drifts from them. A runner that executes
each guard against its fixture now is per-guard harness work, out of this
increment.
