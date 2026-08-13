---
title: Validate Forgejo Workflows
modified: 2026-08-13
last-reviewed: 2026-08-13
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Validate Forgejo Workflows

`forgejo-runner validate` checks every file under `.forgejo/workflows/`
against the runner's own schema — the errors actionlint misses, because
actionlint validates against GitHub's schema and Forgejo accepts and rejects
different keys.

## In CI (the enforcement point)

The Lint workflow's `workflows-validate` job runs on every PR and push to
main. It invokes indri's source-built runner binary directly — the same
binary that executes the workflows, so validation and execution can never
disagree on schema version. There is nothing to install and nothing to
remember; a schema error fails the PR.

## By hand

On **indri**, use the runner's own build:

```fish
ssh indri '~/code/3rd/forgejo-runner/forgejo-runner validate --directory ~/code/personal/blumeops'
```

Anywhere with **docker** (gilbert), the upstream runner image carries the
binary — match the version to `forgejo_runner_version` in
`ansible/roles/forgejo_runner/defaults/main.yml`:

```fish
docker run --rm -v (pwd):/workspace -w /workspace \
    code.forgejo.org/forgejo/runner:12.8.2 \
    forgejo-runner validate --directory .
```

This replaced the `validate_workflows` dagger function and the
`mise run validate-workflows` task, retired when the CI job landed: the
dagger wrapper existed to standardize a docker invocation across
environments, and CI is now the one environment that matters.

## Related

- [[configure-launchd-runner]] — Runner configuration (host-mode on indri)
