The prek hook set now runs on every PR, as a **Lint** workflow alongside Docs
Checks. Until now the hooks ran nowhere: no workflow invoked prek, and no git
hooks are installed in an agent pod, so enforcement was whoever remembered to
run `prek run --all-files` on gilbert. That is not a theoretical gap — it is how
five Python files drifted out of `ruff-format` shape unnoticed, and how ruff came
to have never once looked at `mise-tasks/`, the directory holding most of this
repo's logic.

The runner needed nothing added. `prek`, `actionlint` and `stylua` are already
in `forgejo_runner_host_tools` at revs mirroring `prek.toml`, and `uv` already
runs the extensionless mise-tasks. The toolchain was provisioned for exactly
this and then never wired up.

`actionlint-system` therefore runs here for the first time. A `*-system` hook
runs whatever is on PATH, and an absent binary does not skip — prek reports the
hook FAILED — which is why blumeops' actionlint hook had never caught a workflow
error in either state. The workflows are clean today, verified against actionlint
1.7.12.

Four hooks are skipped, named explicitly in the workflow rather than quietly
omitted, since a lint job that covers less than it appears to is the failure
mode this is meant to end. `ty-check` aborts in any fresh checkout because
`[tool.ty.environment]` points at the gitignored dagger SDK at `sdk/src`;
`validate-workflows` needs Docker Desktop and a dagger engine; `trufflehog` is
pinned to `--since-commit HEAD`, an incremental range that scans nothing on a CI
checkout, and a scan that silently covers nothing is worse than none;
`stylua-system` has no Lua to lint here.

The job also re-runs the three validators Docs Checks already covers. Harmless
duplication, kept so coverage does not depend on which workflow survives; worth
consolidating if it ever becomes noise.
