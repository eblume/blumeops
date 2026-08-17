Agent lint gate: new `mise run agent-lint` runs the PR prek job's hook set
locally (everything except prettier, which needs node) — agent PR checks sit
pending until a human approves the run, so lint failures were discovered
late. `actionlint` joins `mise.toml` so the actionlint-system hook runs in
the pod. Origin: the container-version-check failure on PR #581.
