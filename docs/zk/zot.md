---
id: zot
aliases:
  - zot
  - container-registry
tags:
  - blumeops
---

# Zot Registry Management Log

Zot is an OCI-native container registry running on Indri, providing:
1. Pull-through cache for Docker Hub, GHCR, Quay (avoids rate limits)
2. Private image storage for custom-built containers

## Service Details

- URL: https://registry.ops.eblu.me
- Local port: 5050
- Data directory: ~/zot
- Config: ~/.config/zot/config.json
- Managed via: mcquack LaunchAgent

## Namespace Convention

| Path | Source |
|------|--------|
| `registry.../docker.io/*` | Cached from Docker Hub |
| `registry.../ghcr.io/*` | Cached from GHCR |
| `registry.../quay.io/*` | Cached from Quay |
| `registry.../blumeops/*` | Private images (yours) |

## How It Works

### Pull-Through Cache (Automatic)

When [[minikube]] pulls an image like `docker.io/library/nginx:latest`:
1. Containerd checks zot first (via `host.minikube.internal:5050`)
2. If zot has it cached, returns immediately
3. If not, zot fetches from upstream, caches it, returns to k8s

Cached images appear under their original registry path (e.g., `docker.io/library/nginx`).

### Private Images (Manual Push)

Build and push from gilbert using podman:
```bash
# Build
podman build -t registry.ops.eblu.me/blumeops/myapp:v1 .

# Push to zot
podman push registry.ops.eblu.me/blumeops/myapp:v1

# Use in k8s manifest
image: registry.ops.eblu.me/blumeops/myapp:v1
```

Private images go under `blumeops/*` namespace. Example: the devpi container is at `registry.ops.eblu.me/blumeops/devpi:latest`.

### Security Model

**Network access only** - no authentication configured. Anyone who can reach zot via Tailscale ACL can push/pull any image. Defense is the tailnet boundary.

Zot supports htpasswd/LDAP/OIDC auth if needed in the future.

## Minikube Integration

The [[minikube]] cluster uses zot as a registry mirror via containerd configuration. Managed by the ansible `minikube` role.

From inside minikube, zot is at `host.minikube.internal:5050`. Containerd tries the mirror first, falls back to upstream if not cached.

Mirrors configured for: `registry.ops.eblu.me`, `docker.io`, `ghcr.io`, `quay.io`

## Useful Commands

```bash
# List all cached/pushed images
curl -s http://indri:5050/v2/_catalog | jq

# List tags for an image
curl -s http://indri:5050/v2/blumeops/devpi/tags/list | jq

# Check service status
ssh indri 'launchctl list | grep zot'

# View logs
ssh indri 'tail -f ~/Library/Logs/mcquack.zot.err.log'
```

## Log

### 2026-01-25
- **Migrated from Tailscale serve to Caddy** - now accessible at `registry.ops.eblu.me`
- Retired `tailscale_serve` ansible role (no longer needed)
- Updated minikube containerd config to use new URL
- Updated CI workflows and mise tasks
- Old URL (`registry.tail8d86e.ts.net`) deprecated

### 2026-01-21
- Verified full workflow: podman build on gilbert → push to zot → k8s pull
- Documented security model (network-only auth via Tailscale ACL)
- Updated minikube integration: now uses containerd (docker driver) instead of CRI-O (podman driver)
- Mirror endpoint changed from `host.containers.internal:5050` to `host.minikube.internal:5050`

### 2026-01-19
- Integrated with minikube as CRI-O registry mirror
- All k8s image pulls now go through zot cache automatically

### 2026-01-18
- Initial setup for k8s migration Phase 0
- Configured pull-through cache for Docker Hub, GHCR, Quay
- Exposed via Tailscale service at registry.tail8d86e.ts.net
