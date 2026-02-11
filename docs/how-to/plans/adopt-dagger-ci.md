---
title: "Plan: Adopt Dagger as CI/CD Build Engine"
tags:
  - how-to
  - plans
  - ci-cd
  - dagger
---

# Plan: Adopt Dagger as CI/CD Build Engine

> **Status:** Phase 1 implemented

## Background

BlumeOps CI/CD currently runs on Forgejo Actions (GitHub Actions-compatible). While functional, the system has pain points that are inherent to the GHA ecosystem:

- **Hard to debug** — logs are buried in a web UI, no way to SSH into a running job, no interactive debugging
- **No local iteration** — the only way to test a workflow change is to push and wait for CI
- **Supply chain risk** — community actions are opaque third-party code running in your infrastructure
- **Runner complexity** — the k8s-runner image must bundle every tool any workflow might need (Docker CLI, buildx, skopeo, Node.js, etc.)
- **YAML as programming language** — complex workflows become unreadable

### Why Dagger?

[Dagger](https://dagger.io/) is an open-source (Apache-2.0) build engine built on BuildKit. It addresses every pain point above:

| Pain point | Dagger solution |
|------------|-----------------|
| Can't debug builds | `--interactive` drops you into a shell at the failure point; `.terminal()` adds breakpoints |
| Can't run locally | `dagger call` runs identically on your laptop and in CI — same code path |
| Supply chain risk | Build logic is your own Python code, not third-party actions |
| Runner bloat | Runner only needs Docker + `dagger` CLI; all tools live inside Dagger containers |
| YAML complexity | Pipelines are real Python (classes, decorators, async/await) — not templated YAML |

### What Dagger is NOT

Dagger is a **build engine**, not a CI scheduler. It does not handle triggers, scheduling, or webhooks. We keep Forgejo Actions as a thin trigger layer — its YAML becomes trivially simple (install dagger, run `dagger call`). All actual build logic moves to Python.

### Alternatives Considered

| System | Verdict | Reason |
|--------|---------|--------|
| **BuildKite** | Rejected | No fully self-hosted option (cloud control plane required); no native Forgejo integration; adds external dependency for a homelab |
| **Concourse CI** | Rejected | Fully self-hosted and great debugging (`fly intercept`), but verbose YAML with no built-in templating; small community; 2-4GB RAM overhead for the scheduler; doesn't solve local iteration as cleanly |
| **Earthly** | Not viable | Project discontinued April 2025, all cloud services shut down July 2025 |

Dagger was chosen because it delivers the best local iteration story, supports Python natively, and requires zero infrastructure beyond what we already have (Docker on the runner).

## Architecture

```
┌─────────────────────┐     ┌──────────────────┐
│   Forgejo Actions    │     │   Your terminal   │
│   (trigger layer)    │     │   (local dev)     │
│                      │     │                   │
│  on: push tags       │     │  mise run ...     │
│  → dagger call ...   │     │  → dagger call .. │
└──────────┬───────────┘     └────────┬──────────┘
           │                          │
           ▼                          ▼
    ┌──────────────────────────────────────┐
    │         Dagger Engine (BuildKit)      │
    │                                      │
    │  blumeops-ci Python module           │
    │  ├── build(container_name)           │
    │  ├── publish(container_name, version)│
    │  ├── build_docs(version)             │
    │  ├── release_docs(version, tokens)   │
    │  └── validate()                      │
    └──────────────┬───────────────────────┘
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
       ┌─────┐ ┌──────┐ ┌───────┐
       │ Zot │ │Forgejo│ │ArgoCD │
       │     │ │Pkgs   │ │       │
       └─────┘ └──────┘ └───────┘
```

**Key principle:** The same `dagger call` command runs on your Mac during development and in the Forgejo runner during CI. The Forgejo Actions YAML is a thin shim that parses the trigger event and calls Dagger.

## Dagger Module Structure

```
dagger/
├── dagger.json              # Module metadata, SDK selection
├── pyproject.toml           # Python deps (httpx, etc.)
├── uv.lock                  # Locked dependencies
└── src/blumeops_ci/
    └── __init__.py          # All build functions
```

## Secrets Handling

Dagger has a first-class `Secret` type — values are never logged, cached, or visible in traces.

**From CLI:**
```bash
dagger call release-docs \
  --src=. --version=v1.6.0 \
  --forgejo-token=env:FORGEJO_TOKEN \
  --argocd-token=env:ARGOCD_TOKEN
```

The `env:VARIABLE` syntax reads from environment variables. In Forgejo Actions, secrets are injected as env vars. Locally, a mise task calls `op read` to populate them.

**In Python code:**
```python
@function
async def release_docs(
    self,
    src: dagger.Directory,
    version: str,
    forgejo_token: dagger.Secret,
    argocd_token: dagger.Secret,
) -> str:
    # Token is mounted securely, never exposed in logs
    token = await forgejo_token.plaintext()
```

**Rule of thumb:** Simple API calls (Forgejo package upload) use Python `httpx` directly in the module runtime. CLI tools without good Python libraries (ArgoCD) run in container steps with secrets mounted as env vars via `.with_secret_variable()`.

## Phase 1: Container Builds

Migrate `build-container.yaml` to use Dagger for the build/push logic.

### Dagger Functions

```python
@function
def build(self, src: dagger.Directory, container_name: str) -> dagger.Container:
    """Build a container from containers/<name>/Dockerfile."""
    context = src.directory(f"containers/{container_name}")
    return dag.container().build(context)

@function
async def publish(
    self,
    src: dagger.Directory,
    container_name: str,
    version: str,
    registry: str = "registry.ops.eblu.me",
) -> str:
    """Build and push to zot registry."""
    ctr = self.build(src, container_name)
    ref = f"{registry}/blumeops/{container_name}:{version}"
    return await ctr.publish(ref)
```

### Local Iteration Workflow

```bash
# Build — validates Dockerfile, fast cached feedback
dagger call build --src=. --container-name=devpi

# Build and drop into a shell to inspect the container
dagger call build --src=. --container-name=devpi terminal

# Debug a failure interactively
dagger call --interactive build --src=. --container-name=devpi

# Push a dev tag for testing in k8s (ArgoCD ignores it)
dagger call publish --src=. --container-name=devpi --version=dev

# Publish the real version
dagger call publish --src=. --container-name=devpi --version=v1.1.0
```

### Forgejo Actions Integration

The existing tag-based trigger model is preserved. The workflow becomes a thin Dagger invocation:

```yaml
name: Build Container
on:
  push:
    tags:
      - '*-v[0-9]*'

jobs:
  build:
    runs-on: k8s
    steps:
      - uses: actions/checkout@v4
      - name: Parse tag
        id: parse
        run: |
          TAG="${GITHUB_REF_NAME}"
          CONTAINER="${TAG%-v[0-9]*}"
          VERSION="${TAG#"${CONTAINER}"-}"
          echo "container=$CONTAINER" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
      - name: Publish
        run: |
          curl -fsSL https://dl.dagger.io/dagger/install.sh | sh
          ./bin/dagger call publish \
            --src=. \
            --container-name=${{ steps.parse.outputs.container }} \
            --version=${{ steps.parse.outputs.version }}
```

The composite action (`.forgejo/actions/build-push-image/`), skopeo workaround, and docker save/load dance are all eliminated — that logic lives in the Dagger module.

### Zot Manifest Compatibility

The current workflow uses skopeo because Docker 27's manifest format has issues with zot. Dagger's `.publish()` uses BuildKit's push mechanism, which is different. This **must be tested** during implementation. If BuildKit's push also has zot compatibility issues, the Dagger function can shell out to skopeo inside a container step as a fallback.

### Release Flow (Unchanged)

```bash
mise run container-tag-and-release <container> <version>
# → creates git tag → pushes → Forgejo Action triggers → dagger call publish
```

## Phase 2: Docs Build + Forgejo Packages Migration

Migrate `build-blumeops.yaml` to use Dagger for the build logic and switch from Forgejo releases to Forgejo generic packages for the docs tarball.

### Artifact Migration: Forgejo Releases → Forgejo Packages

**Current:** Docs tarball uploaded as a Forgejo release asset.
```
https://forge.ops.eblu.me/eblume/blumeops/releases/download/v1.5.2/docs-v1.5.2.tar.gz
```

**New:** Docs tarball uploaded to Forgejo generic packages registry.
```
https://forge.ops.eblu.me/api/packages/eblume/generic/blumeops-docs/v1.6.0/docs-v1.6.0.tar.gz
```

This decouples the docs artifact from git releases while keeping the versioned URL pattern. Forgejo releases can still be created for changelog/announcement purposes without carrying the tarball.

### Dagger Functions

```python
@function
async def build_changelog(self, src: dagger.Directory, version: str) -> dagger.Directory:
    """Run towncrier to build changelog, return modified source tree."""
    return await (
        dag.container()
        .from_("python:3.12-slim")
        .with_exec(["pip", "install", "towncrier"])
        .with_directory("/workspace", src)
        .with_workdir("/workspace")
        .with_exec(["towncrier", "build", "--version", version, "--yes"])
        .directory("/workspace")
    )

@function
async def build_docs(self, src: dagger.Directory, version: str) -> dagger.File:
    """Build changelog, then build Quartz site, return tarball."""
    updated_src = await self.build_changelog(src, version)
    return await (
        dag.container()
        .from_("node:20-slim")
        .with_exec(["apt-get", "update", "-qq"])
        .with_exec(["apt-get", "install", "-y", "-qq", "git"])
        .with_directory("/workspace", updated_src)
        .with_workdir("/workspace")
        .with_exec(["git", "clone", "--depth=1",
                     "https://github.com/jackyzha0/quartz.git", "/tmp/quartz"])
        .with_exec(["sh", "-c",
                     "cp -r /tmp/quartz/quartz /tmp/quartz/package*.json "
                     "/tmp/quartz/tsconfig.json ."])
        .with_exec(["npm", "ci"])
        .with_exec(["cp", "docs/quartz.config.ts", "."])
        .with_exec(["cp", "docs/quartz.layout.ts", "."])
        .with_exec(["cp", "CHANGELOG.md", "docs/"])
        .with_exec(["npx", "quartz", "build", "-d", "docs"])
        .with_exec(["sh", "-c",
                     f"tar -czf /docs-{version}.tar.gz -C public ."])
        .file(f"/docs-{version}.tar.gz")
    )

@function
async def upload_docs(
    self,
    tarball: dagger.File,
    version: str,
    forgejo_token: dagger.Secret,
) -> str:
    """Upload docs tarball to Forgejo generic packages."""
    import httpx

    token = await forgejo_token.plaintext()
    await tarball.export(f"/tmp/docs-{version}.tar.gz")

    async with httpx.AsyncClient() as client:
        with open(f"/tmp/docs-{version}.tar.gz", "rb") as f:
            resp = await client.put(
                f"https://forge.ops.eblu.me/api/packages/eblume/generic/"
                f"blumeops-docs/{version}/docs-{version}.tar.gz",
                headers={"Authorization": f"token {token}"},
                content=f.read(),
            )
            resp.raise_for_status()
    return f"https://forge.ops.eblu.me/api/packages/eblume/generic/blumeops-docs/{version}/docs-{version}.tar.gz"

@function
async def release_docs(
    self,
    src: dagger.Directory,
    version: str,
    forgejo_token: dagger.Secret,
    argocd_token: dagger.Secret,
) -> str:
    """Full docs release: build, upload to Forgejo packages, sync ArgoCD."""
    tarball = await self.build_docs(src, version)
    pkg_url = await self.upload_docs(tarball, version, forgejo_token)

    # Sync ArgoCD
    await (
        dag.container()
        .from_("alpine:3.21")
        .with_exec(["apk", "add", "--no-cache", "curl"])
        .with_secret_variable("ARGOCD_AUTH_TOKEN", argocd_token)
        .with_exec(["sh", "-c",
            "curl -fSs -X POST "
            "-H \"Authorization: Bearer $ARGOCD_AUTH_TOKEN\" "
            "\"https://argocd.ops.eblu.me/api/v1/applications/docs/sync\" "
            "-d '{}'"])
        .sync()
    )

    return pkg_url
```

### Local Iteration Workflow

```bash
# Test the full docs build locally — identical to CI
dagger call build-docs --src=. --version=dev export --path=./docs-dev.tar.gz

# Inspect the output
tar tf docs-dev.tar.gz | head -20

# Debug a Quartz build failure interactively
dagger call --interactive build-docs --src=. --version=dev

# Test just the changelog build
dagger call build-changelog --src=. --version=dev export --path=./updated-src/
```

This is particularly valuable for debugging Quartz build issues and for iterating on a personal quartz fork.

### Forgejo Actions Integration

The workflow remains manually triggered (workflow_dispatch) to preserve centralized version sequencing. Dagger handles the build/upload/deploy; the workflow handles version resolution and git commit:

```yaml
name: Build BlumeOps
on:
  workflow_dispatch:
    inputs:
      version_type: { type: choice, options: [BUMP_PATCH, BUMP_MINOR, BUMP_MAJOR] }

jobs:
  release:
    runs-on: k8s
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Resolve version
        id: version
        run: |
          # ... existing version bump logic (query Forgejo API, bump semver) ...

      - name: Build, upload, and deploy
        env:
          FORGEJO_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ARGOCD_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          curl -fsSL https://dl.dagger.io/dagger/install.sh | sh
          ./bin/dagger call release-docs \
            --src=. --version=${{ steps.version.outputs.version }} \
            --forgejo-token=env:FORGEJO_TOKEN \
            --argocd-token=env:ARGOCD_TOKEN

      - name: Export changelog changes
        run: |
          ./bin/dagger call build-changelog \
            --src=. --version=${{ steps.version.outputs.version }} \
            export --path=.

      - name: Update manifest and commit
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          URL="https://forge.ops.eblu.me/api/packages/eblume/generic/blumeops-docs/${VERSION}/docs-${VERSION}.tar.gz"
          sed -i "s|value: \"https://.*\"|value: \"${URL}\"|" \
            argocd/manifests/docs/deployment.yaml
          git config user.name "Forgejo Actions"
          git config user.email "actions@forge.ops.eblu.me"
          git add CHANGELOG.md docs/changelog.d/ argocd/manifests/docs/deployment.yaml
          git commit -m "Release docs $VERSION [skip ci]"
          git push origin HEAD:main
```

### Manifest Update

The quartz container's `DOCS_RELEASE_URL` env var in `argocd/manifests/docs/deployment.yaml` must be updated to use the Forgejo packages URL format:

```yaml
# Before (Forgejo releases):
- name: DOCS_RELEASE_URL
  value: "https://forge.ops.eblu.me/eblume/blumeops/releases/download/v1.5.2/docs-v1.5.2.tar.gz"

# After (Forgejo generic packages):
- name: DOCS_RELEASE_URL
  value: "https://forge.ops.eblu.me/api/packages/eblume/generic/blumeops-docs/v1.6.0/docs-v1.6.0.tar.gz"
```

The quartz container's `start.sh` already downloads from `DOCS_RELEASE_URL` via curl — no container changes needed, just the URL format changes.

## Phase 3: Runner Simplification

Once container builds and docs builds both use Dagger, the k8s-runner image can be simplified.

### Current Runner Requirements

The `forgejo-runner` container (at `containers/forgejo-runner/`) bundles:
- Docker CLI + buildx plugin (for container builds)
- Skopeo (for zot push compatibility)
- Node.js (for Quartz docs builds)
- ArgoCD CLI (for deployment sync)
- Various other tools

### Simplified Runner

With Dagger, the runner only needs:
- Docker (for the Dagger engine — already available via DinD sidecar)
- The `dagger` CLI binary
- Git (for checkout)
- Basic shell utilities

All other tools (Node.js, skopeo, argocd, Python, npm) live inside the Dagger containers defined by the module. Adding a new tool to a build never requires rebuilding the runner image.

### Implementation

Update `containers/forgejo-runner/Dockerfile` to remove tool-specific dependencies. Install the `dagger` CLI instead. The DinD sidecar in the Forgejo runner pod (`argocd/manifests/forgejo-runner/`) stays unchanged — Dagger's engine runs inside Docker, which the sidecar provides.

## Phase 4: Future Workflows

These are natural extensions once the Dagger module is established:

### Forked Project Builds

Once the [[upstream-fork-strategy]] is in place, forked projects (e.g., a personal quartz fork) can use the same Dagger patterns for building. The docs build function could accept a quartz source directory parameter instead of cloning upstream, enabling builds against the fork.

### Python Package Builds

If private Python packages are built for [[devpi]], Dagger is a natural fit:

```bash
dagger call build-package --src=. --version=v1.0.0
# → builds wheel/sdist → uploads to devpi
```

### Pre-Merge Validation

A `validate` function that runs linting, doc link checks, and other pre-merge checks:

```bash
dagger call validate --src=.
# → runs docs-check-links, docs-check-index, docs-check-filenames, etc.
```

Same checks run locally and in CI. Could be triggered by Forgejo Actions on PR creation.

## Caveats and Risks

### Dagger Is Pre-1.0

Current version is v0.19.x. API breakage between versions is possible. Mitigations:
- Pin the Dagger CLI version in the runner image and local install
- Test upgrades on a branch before adopting
- The module is small enough to update quickly if APIs change

### Privileged Container Requirement

The Dagger engine requires privileged container access. The current Forgejo runner already uses DinD (privileged), so this should work. Must be verified during implementation.

### BuildKit Cache Persistence

BuildKit caches aggressively, making repeated builds fast. Since the Forgejo runner pod is persistent (not ephemeral), the cache persists between CI runs. Locally, the Dagger engine maintains its own cache. No special cache configuration should be needed.

## Verification Checklist

### Phase 1 (Containers)
- [x] `dagger call build --src=. --container-name=nettest` succeeds locally
- [ ] `dagger call build --src=. --container-name=nettest terminal` drops into container shell
- [x] `dagger call publish --src=. --container-name=nettest --version=test` pushes to zot
- [x] Zot manifest compatibility confirmed (no skopeo needed) or fallback implemented
- [x] Tag-triggered Forgejo Action successfully calls `dagger call publish`
- [x] Existing `mise run container-tag-and-release` workflow still works end-to-end

### Phase 2 (Docs)
- [ ] `dagger call build-docs --src=. --version=dev` produces valid tarball locally
- [ ] Tarball contents match current Quartz build output
- [ ] `dagger call release-docs` uploads to Forgejo packages successfully
- [ ] Quartz container starts and serves docs from Forgejo packages URL
- [ ] ArgoCD sync works from within Dagger
- [ ] Forgejo Actions workflow_dispatch completes full release cycle
- [ ] CHANGELOG.md and fragment cleanup committed correctly

### Phase 3 (Runner)
- [ ] Simplified runner image builds and runs
- [ ] Dagger engine starts inside the runner's DinD environment
- [ ] All existing workflows pass with the simplified runner

## How-To Articles to Write

The following how-to guides should be created alongside implementation:

| Article | Description |
|---------|-------------|
| `docs/how-to/use-dagger-containers.md` | Creating and iterating on containers with Dagger (build, terminal, publish workflow) |
| `docs/how-to/release-docs.md` | Updated docs release process using Dagger + Forgejo packages (replaces current [[update-documentation]]) |

## Reference

| File | Purpose |
|------|---------|
| `.forgejo/workflows/build-container.yaml` | Current container build workflow (to be migrated) |
| `.forgejo/workflows/build-blumeops.yaml` | Current docs build workflow (to be migrated) |
| `.forgejo/actions/build-push-image/action.yaml` | Current composite action (to be removed) |
| `containers/forgejo-runner/Dockerfile` | Runner image (to be simplified) |
| `argocd/manifests/forgejo-runner/` | Runner k8s manifests |
| `argocd/manifests/docs/deployment.yaml` | Docs deployment (DOCS_RELEASE_URL to update) |

## Related

- [[upstream-fork-strategy]] — Forking strategy plan (future Dagger integration)
- [[forgejo]] — CI/CD infrastructure
- [[zot]] — Container registry
- [[apps]] — ArgoCD application registry
