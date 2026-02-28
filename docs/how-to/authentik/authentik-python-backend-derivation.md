---
title: Build Authentik Python Backend
modified: 2026-02-28
status: active
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik Python Backend

Build `authentik-django` — the Python/Django application that forms the core backend of authentik.

## Context

This is the most complex component. The nixpkgs derivation uses `python3.override` with extensive `packageOverrides` to handle authentik's non-standard dependencies:

- **4 in-tree Python packages** built from the monorepo: `ak-guardian`, `django-channels-postgres`, `django-dramatiq-postgres`, `django-postgres-cache`
- **Forked `djangorestframework`** from `authentik-community/django-rest-framework` (specific commit)
- **Pinned `dramatiq`** at 1.17.1 (upstream uses newer versions that break authentik)
- **Django 5** forced via `django_5`
- **60+ Python dependencies** from nixpkgs

Post-install, the derivation patches hardcoded paths in `settings.py`, `default.yml`, `email/utils.py`, and `files/backends/file.py` to reference Nix store paths.

## What to Do

1. Create a Python package override set that builds the 4 in-tree packages from source
2. Pin the forked `djangorestframework` and `dramatiq` versions
3. Build `authentik-django` using `hatchling` as the build backend
4. Apply the 4 `substituteInPlace` patches for Nix store path references
5. Copy lifecycle scripts, `manage.py`, blueprints, and web assets into the output
6. Verify: `python -c "import authentik"` succeeds

## Key Details

- Build backend: `hatchling`
- Entry point: `manage.py` (Django management commands)
- Lifecycle scripts: `lifecycle/` directory (used by Go server and `ak` wrapper)
- Blueprints: `blueprints/` directory (YAML IaC definitions)
- The output must include `web/` assets (email templates reference them)

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-go-server-derivation]] — Depends on this for lifecycle scripts and web assets
