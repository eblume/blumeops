---
title: Validate Workflows Against v12
status: active
modified: 2026-02-22
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Validate Workflows Against v12

Run `forgejo-runner validate` (available from v9.0+) against all workflow files to catch schema issues before upgrading the k8s runner daemon.

## Background

Forgejo-runner v8.0 introduced workflow schema validation — workflows that don't pass are rejected at runtime. v9.0 made this stricter and added a `validate` CLI command. Since we're jumping from v6.3.1, we've never run validation. All six workflows in `.forgejo/workflows/` need checking.

## Approach: Dagger Pipeline

Add a `validate_workflows` function to the [[dagger]] module (`.dagger/src/blumeops_ci/main.py`). This runs `forgejo-runner validate` inside the upstream runner container — no host-side binary management, reproducible, and version-pinned.

```python
@function
async def validate_workflows(
    self,
    src: dagger.Directory,
    runner_version: str = "12.7.0",
) -> str:
    """Validate Forgejo Actions workflow files against runner schema."""
    return await (
        dag.container()
        .from_(f"code.forgejo.org/forgejo/runner:{runner_version}")
        .with_directory("/workspace", src)
        .with_workdir("/workspace")
        .with_exec([
            "sh", "-c",
            "for f in .forgejo/workflows/*.yaml; do "
            '  echo "=== $f ===" && forgejo-runner validate "$f"; '
            "done"
        ])
        .stdout()
    )
```

Invoke locally with:

```fish
dagger call validate-workflows --src=.
```

### Permanent guardrail

Once the function exists, wire it into CI as a pre-commit hook or a mise task (`mise run validate-workflows`). This prevents future workflow regressions regardless of runner version changes. The `runner_version` parameter lets us pin to whatever version the k8s runner is actually running.

## Workflows to Validate

| File | Complexity | Notes |
|------|-----------|-------|
| `build-container.yaml` | High | Matrix strategy, conditional steps |
| `build-container-nix.yaml` | High | Matrix strategy, conditional steps |
| `build-blumeops.yaml` | High | Multi-step release pipeline |
| `deploy-fly.yaml` | Low | Simple deploy |
| `cv-deploy.yaml` | Medium | Version resolution + deploy |
| `branch-cleanup.yaml` | Low | Scheduled + manual dispatch |

## Fix any failures

If validation fails, fix the workflow schema issues in the same PR as the runner upgrade. Common issues in the v8/v9 changelog:
- Invalid `type:` values in `workflow_dispatch.inputs`
- Incorrect `if:` expression syntax
- Undeclared or misspelled keys

## Deliverables

1. `validate_workflows` function in `.dagger/src/blumeops_ci/main.py`
2. All 6 workflows passing validation (fix any schema issues)
3. A mise task or pre-commit hook wiring `dagger call validate-workflows` for ongoing use

## Related

- [[upgrade-k8s-runner]] — Parent goal
