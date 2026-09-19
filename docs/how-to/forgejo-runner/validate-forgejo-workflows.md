---
title: Validate Forgejo Workflows
modified: 2026-09-19
last-reviewed: 2026-09-04
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
main. It builds the nixpkgs runner from the [[indri]] flake's pinned nixpkgs
input — the same package the generation's unit runs — and invokes it
directly, so validation and execution can never disagree on schema
version. There is nothing to install and nothing to remember; a schema
error fails the PR.

## By hand

On **indri**, build the same nixpkgs package the unit runs:

```fish
ssh indri 'runner_bin="$(nix build --no-link /etc/blumeops/darwin/indri#forgejo-runner --print-out-paths)/bin/forgejo-runner"; "$runner_bin" validate --directory ~/code/personal/blumeops'
```

Anywhere with **docker** (gilbert), the upstream runner image carries the
binary — match the version to the [[indri]] flake's nixpkgs pin
(13.1.0):

```fish
docker run --rm -v (pwd):/workspace -w /workspace \
    code.forgejo.org/forgejo/runner:13.1.0 \
    forgejo-runner validate --directory .
```

This replaced the `validate_workflows` dagger function and the
`mise run validate-workflows` task, retired when the CI job landed: the
dagger wrapper existed to standardize a docker invocation across
environments, and CI is now the one environment that matters.

## Related

- [[configure-launchd-runner]] — Runner configuration (host-mode on indri)
