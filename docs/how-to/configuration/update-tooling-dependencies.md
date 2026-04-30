---
title: Update Tooling Dependencies
modified: 2026-02-23
last-reviewed: 2026-02-23
tags:
  - how-to
  - configuration
aliases: []
id: update-tooling-dependencies
---

# Update Tooling Dependencies

Monthly maintenance cycle for updating development tooling and CI dependencies. This is separate from [[review-services]], which tracks deployed service versions.

## Scope

| Category | Location | What to check |
|----------|----------|---------------|
| Prek hooks | `prek.toml` | `rev:` tags for all remote repos |
| Fly.io proxy | `fly/Dockerfile` | Pinned image tags (nginx, alloy) |
| Mise task scripts | `mise-tasks/*` | Python `# dependencies` lower bounds |
| Forgejo workflows | `.forgejo/workflows/*.yaml` | `uses:` action versions |

Out of scope: ArgoCD-deployed service images, Ansible role versions, NixOS flake inputs. Those are covered by [[review-services]] and [[manage-lockfile]].

## Procedure

### 1. Check prek hook versions

For each repo in `prek.toml` with a `rev =` value, check the upstream GitHub releases page for a newer tag. Update each `rev` to the **commit SHA** of the latest release with a trailing `# vX.Y.Z` comment (matches the `additional_dependencies` and Forgejo workflow pinning style). Also check `additional_dependencies` entries for PyPI version bumps and pin them with `==`.

```fish
git ls-remote --tags https://github.com/<owner>/<repo>.git 'refs/tags/v*' | sort -t/ -k3 -V | tail -5
```

Clear the prek cache before verifying — it can grow to several GiB (one venv per hook per version) and old cached environments can mask resolution failures or stale catalogs:

```fish
prek clean
prek run --all-files
```

### 2. Check Fly.io Dockerfile pins

Review `fly/Dockerfile` for pinned image digests. Each `FROM` and `COPY --from=` uses `image@sha256:...` digest pinning with a comment line above documenting the human-readable version.

- **nginx** — check [Docker Hub](https://hub.docker.com/_/nginx) for latest stable alpine tag
- **grafana/alloy** — check [GitHub releases](https://github.com/grafana/alloy/releases)
- **tailscale/tailscale** — pinned to a known-good version. Do not bump to v1.96.5 or later (MagicDNS regression breaks the proxy boot)

To resolve a tag to a digest:

```fish
docker buildx imagetools inspect docker.io/<image>:<tag>
# Use the top-level "Digest:" line (multi-arch index) — not the per-platform sub-digest
```

After updating, the deploy-fly workflow will build and deploy on merge to main. Verify with `fly status -a blumeops-proxy` after deploy.

### 3. Pin mise task dependencies

Mise tasks use `uv run --script` with inline PEP 723 dependency metadata. All packages are pinned with `==` (PEP 508 doesn't support hashes inline). Check that pinned versions are consistent across all scripts:

```fish
grep -r 'dependencies' mise-tasks/ | grep '# dependencies'
```

For each package in use (`httpx`, `rich`, `typer`, `pyyaml`), pick the latest PyPI version and update every script in lockstep — divergence between scripts is the failure mode this catches. Bump everything together; don't leave one script behind.

### 4. Pin Forgejo workflow action versions

All `uses:` directives in `.forgejo/workflows/*.yaml` must reference upstream actions by **commit SHA**, not mutable tags. This prevents supply-chain attacks where a tag is moved to point at malicious code.

Format: `uses: actions/checkout@<full-sha> # v4.3.1`

The trailing comment documents the human-readable version. To update:

```fish
git ls-remote --tags https://github.com/actions/checkout.git 'refs/tags/v4*' | sort -t/ -k3 -V | tail -5
```

Pick the latest patch tag, note its SHA, and update all occurrences across the workflow files.

### 5. Commit and create PR

Create a single PR with all dependency bumps. The changelog fragment type is `infra`.

## Notes

- **Alloy version gaps**: Grafana Alloy releases frequently. Large version jumps (e.g., v1.5 to v1.13) are normal and generally safe — check the [changelog](https://github.com/grafana/alloy/releases) for breaking changes in the Alloy River config syntax.
- **Ruff minor bumps**: Ruff adds new lint rules in minor versions. A bump may surface new warnings. Run `prek run ruff --all-files` to check before committing.
- **shellcheck bumps**: New shellcheck versions may flag previously-ignored patterns. Review any new failures before updating.
