# prek-present

Invariant: every managed repo has a `prek.toml` at its root that parses as TOML.
prek is the one git-hook and lint runner across the fleet; a repo without a
readable config runs no shared hooks at all. Missing or malformed is one
violation.

Alternatives rejected: checking for `.pre-commit-config.yaml` (the fleet standard
is prek, and a pre-commit file is not a substitute) and validating the hook
contents (that belongs to each repo's own hooks; this aspect checks only that the
entry point exists and is readable).

**Scope.** The aspect runs in every managed repo (no `APPLIES_TO`). It reads only
the top-level `prek.toml` of the target root.
