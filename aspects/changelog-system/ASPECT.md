# changelog-system

Invariant: every managed repo has a changelog system. A repo passes if it has
`towncrier.toml`, a `[tool.towncrier]` table in `pyproject.toml`, or a
`release-notes/` directory (talos and horkos keep per-minor release notes and
patch-release on every merge; that is their changelog). Anything else is one
violation.

Alternatives rejected: checking only for `docs/changelog.d/` (it would fail the
release-notes repos, whose changelog is a different shape) and checking for a
CHANGELOG.md file (a hand-edited file is not a system that fragments can feed).

**Scope.** The aspect runs in every managed repo (no `APPLIES_TO`). It reads only
top-level paths of the target root, so the aspect's own fixtures under
`aspects/` are never graded.
