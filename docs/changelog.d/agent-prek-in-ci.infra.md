The prek hook set now runs on every PR, as a **Lint** workflow alongside Docs
Checks. Until now the hooks ran nowhere: no workflow invoked prek, and no git
hooks are installed in an agent pod, so enforcement was whoever remembered to
run `prek run --all-files` on gilbert. That is not a theoretical gap — it is how
five Python files drifted out of `ruff-format` shape unnoticed, and how ruff came
to have never once looked at `mise-tasks/`, the directory holding most of this
repo's logic.

The runner needed nothing added. `prek` and `actionlint` are already in
`forgejo_runner_host_tools` at revs mirroring `prek.toml`, and `uv` already runs
the extensionless mise-tasks. The toolchain was provisioned for exactly this and
then never wired up.

`actionlint-system` therefore runs here for the first time. A `*-system` hook
runs whatever is on PATH, and an absent binary does not skip — prek reports the
hook FAILED — which is why blumeops' actionlint hook had never caught a workflow
error in either state. The workflows are clean today, verified against actionlint
1.7.12.

**Three hooks are removed rather than skipped**, because CI is now the
enforcement point and a hook that cannot run in a clean checkout is one nobody
is running:

- `ty-check` — `[tool.ty.environment]` points at `sdk/src`, the dagger-generated
  SDK. `/sdk/` is gitignored, so ty aborts in *any* fresh checkout, CI or local.
- `validate-workflows` — shells to `dagger call`, needing Docker Desktop and an
  engine container. Still available as `mise run validate-workflows`.
- `trufflehog` — pinned to `--since-commit HEAD`, an incremental range that
  scans nothing on a fresh checkout.

Removing beats skipping: a skip list is a second place to drift, and it lets
`prek.toml` keep accumulating hooks that only appear to run. What is left is
25 hooks that all pass, so the job's result is the whole of what the hook set
checks.

Two of these are real capabilities and their loss is not free. **Secret scanning
is now the builtin `detect-private-key` alone**, which catches private keys and
nothing else — on a repo whose first rule is that it is public. Workflow *schema*
validation is likewise gone, though actionlint covers much of the same ground.
Both are tracked for a CI-shaped rebuild rather than reinstatement as-is.
