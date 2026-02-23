---
title: Update Tooling Dependencies
modified: 2026-02-23
last-reviewed: 2026-02-23
tags:
  - how-to
  - configuration
---

# Update Tooling Dependencies

Monthly maintenance cycle for updating development tooling and CI dependencies. This is separate from [[review-services]], which tracks deployed service versions.

## Scope

| Category | Location | What to check |
|----------|----------|---------------|
| Pre-commit hooks | `.pre-commit-config.yaml` | `rev:` tags for all remote repos |
| Fly.io proxy | `fly/Dockerfile` | Pinned image tags (nginx, alloy) |
| Mise task scripts | `mise-tasks/*` | Python `# dependencies` lower bounds |
| Forgejo workflows | `.forgejo/workflows/*.yaml` | `uses:` action versions |

Out of scope: ArgoCD-deployed service images, Ansible role versions, NixOS flake inputs. Those are covered by [[review-services]] and [[manage-lockfile]].

## Procedure

### 1. Check pre-commit hook versions

For each repo in `.pre-commit-config.yaml` with a `rev:` tag, check the upstream GitHub releases page for a newer tag. Update each `rev:` to the latest release tag. Also check `additional_dependencies` entries for PyPI version bumps.

Verify after updating:

```fish
uvx pre-commit run --all-files
```

### 2. Check Fly.io Dockerfile pins

Review `fly/Dockerfile` for pinned image tags:

- **nginx** — check [Docker Hub](https://hub.docker.com/_/nginx) for latest stable alpine tag
- **grafana/alloy** — check [GitHub releases](https://github.com/grafana/alloy/releases)
- **tailscale/tailscale** — uses `stable` rolling tag, no action needed

After updating, the deploy-fly workflow will build and deploy on merge to main. Verify with `fly status -a blumeops-proxy` after deploy.

### 3. Normalize mise task dependency bounds

Mise tasks use `uv run --script` with inline PEP 723 dependency metadata. Check that lower bounds are consistent across all scripts:

```fish
grep -r 'dependencies' mise-tasks/ | grep '# dependencies'
```

Ensure all scripts using the same package agree on the minimum version. When a package has a new major or breaking minor release, bump the lower bound across all scripts at once.

### 4. Check Forgejo workflow action versions

Review `.forgejo/workflows/*.yaml` for `uses:` directives. Currently all workflows use `actions/checkout@v4` which tracks the latest v4.x.

### 5. Commit and create PR

Create a single PR with all dependency bumps. The changelog fragment type is `infra`.

## Notes

- **Alloy version gaps**: Grafana Alloy releases frequently. Large version jumps (e.g., v1.5 to v1.13) are normal and generally safe — check the [changelog](https://github.com/grafana/alloy/releases) for breaking changes in the Alloy River config syntax.
- **Ruff minor bumps**: Ruff adds new lint rules in minor versions. A bump may surface new warnings. Run `uvx pre-commit run ruff --all-files` to check before committing.
- **shellcheck bumps**: New shellcheck versions may flag previously-ignored patterns. Review any new failures before updating.
