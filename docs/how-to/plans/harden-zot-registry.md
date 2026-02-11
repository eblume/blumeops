---
title: "Plan: Harden Zot Registry"
tags:
  - how-to
  - plans
  - zot
  - registry
  - security
---

# Plan: Harden Zot Registry

> **Status:** Planned (not yet executed)
> **Sequence:** Execute after [[adopt-dagger-ci]] and [[adopt-oidc-provider]] — the Dagger migration will change how images are built and pushed, and the OIDC provider supplies the identity layer that zot's auth and API key features depend on.

## Background

Zot is the BlumeOps OCI container registry, running natively on [[indri]]. It serves two roles: a pull-through cache for upstream registries (Docker Hub, GHCR, Quay) and the private image store for `blumeops/*` images.

Currently, zot has **no authentication** — the security boundary is the Tailscale ACL. This was an acceptable starting point, but has two gaps:

1. **Any tailnet client can push images** — there's no distinction between pull (which k8s pods need) and push (which only CI should do). A compromised service or misconfigured pod could overwrite production images.
2. **Tags are mutable** — pushing the same tag twice silently overwrites the previous image. There's no protection against accidental or malicious tag clobbering.

### Goals

- **Authenticated push** — only CI (Forgejo Actions / Dagger) can push images; all other clients are pull-only
- **Tag immutability** — once a version tag is pushed, it cannot be overwritten
- **No disruption to pulls** — k8s pods and pull-through caching continue to work without authentication
- **Minimal complexity** — use zot's built-in OIDC and API key features with the BlumeOps identity provider

## Current State

### Push Mechanism

Images are currently pushed via the composite action at `.forgejo/actions/build-push-image/action.yaml`:

1. `docker buildx build` creates the image
2. `docker save` exports to a tarball
3. `skopeo copy` pushes to `registry.ops.eblu.me` (no credentials needed)

The action pushes two tags per build: a version tag (e.g., `v1.2.0`) and the git commit SHA.

### Zot Configuration

The config template (`ansible/roles/zot/templates/config.json.j2`) has no `accessControl` or `http.auth` section. The HTTP listener binds to `0.0.0.0:5050` with no TLS (Caddy terminates TLS at `registry.ops.eblu.me`).

## Plan

### 1. Add Authentication for Push (OIDC + API Keys)

Zot supports native OIDC authentication with a built-in API key feature designed for exactly this use case. The approach:

1. **OIDC for browser login** — zot delegates authentication to the BlumeOps OIDC provider (see [[adopt-oidc-provider]]). Human users log in via browser redirect.
2. **API keys for CI** — after logging in via OIDC, generate a scoped API key for Forgejo CI / Dagger. API keys are zot-native tokens (`zak_...`) that work with `docker login`, `skopeo`, and Dagger's `with_registry_auth()`. They can be scoped to specific repositories and given expiration dates.
3. **Access control** — `anonymousPolicy` allows unauthenticated pull; push requires authentication.

```json
{
  "http": {
    "auth": {
      "openid": {
        "providers": {
          "oidc": {
            "name": "BlumeOps",
            "credentialsFile": "/Users/erichblume/.config/zot/oidc-credentials.json",
            "issuer": "https://dex.ops.eblu.me",
            "scopes": ["openid", "profile", "email"]
          }
        }
      },
      "apikey": true
    },
    "accessControl": {
      "repositories": {
        "**": {
          "anonymousPolicy": ["read"],
          "defaultPolicy": ["read", "create", "update"],
          "policies": [
            {
              "users": ["eblume"],
              "actions": ["read", "create", "update", "delete"]
            }
          ]
        }
      },
      "adminPolicy": {
        "users": ["eblume"],
        "actions": ["read", "create", "update", "delete"]
      }
    }
  }
}
```

The OIDC credentials file (client ID and secret) is deployed by Ansible from 1Password — never committed to the repo.

**CI push flow after setup:**
1. Log in to zot UI via browser (OIDC redirect to Dex)
2. Generate an API key: `POST /zot/auth/apikey` with label `forgejo-ci`, scoped to `blumeops/**`
3. Store the key in 1Password (`op://blumeops/zot-ci-apikey/credential`)
4. CI uses the key: `docker login -u eblume -p zak_... registry.ops.eblu.me`

This ensures:
- k8s pods, minikube containerd, and pull-through caching all continue to work anonymously (read-only)
- Push requires a valid API key tied to an OIDC identity
- No standalone password files (htpasswd) to manage — identity flows from the central IdP

### 2. Enforce Tag Immutability

Zot does not have a built-in tag immutability feature at the registry level. Options to consider during execution:

- **Registry-side:** Check if newer zot versions (post-2.1) have added immutability policies. If so, configure in `config.json`.
- **Push-side enforcement:** The simpler approach — check whether a tag already exists before pushing. The current build-push-image action (and its eventual Dagger replacement) should query the registry API (`GET /v2/<name>/tags/list`) and **fail the build** if the version tag already exists. Commit SHA tags are inherently unique and don't need this check.

The push-side approach is pragmatic: it prevents accidental overwrites in the normal CI flow. Combined with authenticated push, a tag can only be overwritten by someone with CI credentials who deliberately bypasses the check.

> **See:** `.forgejo/actions/build-push-image/action.yaml` — this is where the pre-push tag check would be added in the current workflow. After [[adopt-dagger-ci]], the equivalent check goes in the Dagger `Container.publish()` wrapper.

### 3. Update Ansible Role

The `ansible/roles/zot/` role needs:

- **New template:** `oidc-credentials.json.j2` (client ID and secret for the Dex OIDC client)
- **Updated config template:** `config.json.j2` gains `http.auth` (openid + apikey) and `accessControl` sections
- **Updated config template:** `config.json.j2` gains `externalUrl` set to `https://registry.ops.eblu.me` (required for OIDC callback redirects behind Caddy)
- **New variables:** `zot_oidc_client_id` and `zot_oidc_client_secret` sourced from 1Password in the playbook's `pre_tasks`
- **Handler:** restart zot LaunchAgent after config changes (already exists)

### 4. Update CI Push Credentials

After [[adopt-dagger-ci]], the Dagger module will use the zot API key for registry auth:

```python
api_key = dag.set_secret("registry-api-key",
    os.environ["ZOT_CI_API_KEY"])
container.with_registry_auth("registry.ops.eblu.me", "eblume", api_key)
container.publish("registry.ops.eblu.me/blumeops/image:tag")
```

### 5. Update Minikube Containerd Config

The minikube containerd config (`ansible/roles/minikube/tasks/main.yml`) currently talks to zot without credentials. Since anonymous pull remains allowed, **no changes are needed** for containerd.

## Execution Steps

1. **Prerequisite: OIDC provider is running** (see [[adopt-oidc-provider]])
   - Dex (or chosen provider) is deployed and serving `https://dex.ops.eblu.me`
   - A zot OIDC client is registered with the provider

2. **Update Ansible role**
   - Add OIDC credentials template
   - Update `config.json.j2` with auth (openid + apikey) and access control
   - Store OIDC client credentials in 1Password
   - Test with `mise run provision-indri -- --tags zot --check --diff`

3. **Deploy and verify pulls still work**
   - `mise run provision-indri -- --tags zot`
   - Verify anonymous pull: `curl -sf https://registry.ops.eblu.me/v2/_catalog`
   - Verify unauthenticated push fails: `skopeo copy ... docker://registry.ops.eblu.me/blumeops/test:fail` (should get 401)

4. **Set up OIDC login and generate CI API key**
   - Log in to zot UI via browser (OIDC flow through Dex)
   - Generate an API key for CI use, store in 1Password
   - Verify authenticated push works: `docker login -u eblume -p zak_... registry.ops.eblu.me`

5. **Add tag immutability check to push workflow**
   - Add pre-push tag existence check to Dagger module (or build-push-image action)
   - Test by attempting to push an existing tag

6. **Update documentation**
   - Update `docs/reference/services/zot.md` security model section
   - Add changelog fragment

## Verification Checklist

- [ ] Anonymous pull works (k8s pods, containerd, curl)
- [ ] Pull-through caching still works (pull an uncached image from docker.io)
- [ ] Unauthenticated push is rejected (401)
- [ ] OIDC browser login works (redirect to Dex and back)
- [ ] API key generation works from zot UI
- [ ] Authenticated push with API key succeeds
- [ ] Pushing a duplicate version tag fails (immutability check)
- [ ] Pushing a new commit SHA tag succeeds
- [ ] Grafana dashboard still shows zot metrics
- [ ] `mise run services-check` passes

## Open Questions

- **Immutability granularity:** Should immutability apply only to semver tags (`v*`) or also to commit SHA tags? SHA tags are unique by nature, so immutability is only meaningful for version tags.
- **API key rotation:** API keys can have expiration dates. Decide on a rotation policy — e.g., annual expiry with a reminder, or no expiry with manual rotation.

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot/templates/config.json.j2` | Current zot config (no auth) |
| `ansible/roles/zot/tasks/main.yml` | Zot deployment tasks |
| `ansible/roles/zot/defaults/main.yml` | Zot default variables |
| `.forgejo/actions/build-push-image/action.yaml` | Current image push workflow (skopeo) |
| `ansible/roles/minikube/tasks/main.yml` | Containerd registry mirror config |
| `docs/reference/services/zot.md` | Zot reference documentation |

## Related

- [[adopt-oidc-provider]] — OIDC identity provider (execute first)
- [[adopt-dagger-ci]] — CI/CD engine migration (execute first)
- [[zot]] — Zot reference card
- [[forgejo]] — CI platform that pushes images
- [[cluster]] — Registry consumer
