# fragment-hook-wired

Invariant with two requirements. (i) Every managed repo's CI runs
prek: some `.forgejo/workflows/*.yaml|yml` has an uncommented line running
`prek run`. (ii) Every towncrier repo (`towncrier.toml`, or a `[tool.towncrier]`
table in `pyproject.toml`) wires the `changelog-fragment` hook in its `prek.toml`,
so a branch cannot merge without a fragment. Each unmet requirement is one
violation.

Alternatives rejected: a bespoke CI job per repo that greps for the fragment
(duplicates logic per repo and drifts), and requiring the hook in every repo
(release-notes repos have no fragments to check).

**Scope.** The aspect runs in every managed repo (no `APPLIES_TO`). Requirement (ii)
applies to towncrier repos only; talos and horkos keep `release-notes/` and are
exempt from the hook, so they fail only if they lack the CI prek run. The aspect
reads only top-level paths and `.forgejo/workflows/` of the target root.
