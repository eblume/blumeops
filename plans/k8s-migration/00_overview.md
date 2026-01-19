# Blumeops Minikube Migration Plan

This plan details a phased migration of blumeops services from direct hosting on indri (Mac Mini M1) to a minikube cluster, while maintaining critical infrastructure services outside of Kubernetes.

## Phases

| Phase | Name | Status | Description |
|-------|------|--------|-------------|
| 0 | [Foundation](P0_foundation.complete.md) | Complete | Container registry + minikube cluster |
| 1 | [K8s Infrastructure](P1_k8s_infrastructure.md) | In Progress | Tailscale operator, ArgoCD, CloudNativePG, PostgreSQL cluster |
| 2 | [Grafana](P2_grafana.md) | Pending | Migrate Grafana (pilot) via ArgoCD |
| 3 | [PostgreSQL](P3_postgresql.md) | Pending | Data migration to k8s PostgreSQL |
| 4 | [Miniflux](P4_miniflux.md) | Pending | Migrate Miniflux via ArgoCD |
| 5 | [devpi](P5_devpi.md) | Pending | Migrate devpi via ArgoCD |
| 6 | [Kiwix](P6_kiwix.md) | Pending | Migrate Kiwix via ArgoCD |
| 7 | [Forgejo](P7_forgejo.md) | Pending | Migrate Forgejo (highest risk) via ArgoCD |
| 8 | [Woodpecker](P8_woodpecker.md) | Pending | Deploy CI/CD via ArgoCD |
| 9 | [Cleanup](P9_cleanup.md) | Pending | Remove deprecated services |

## Architecture Overview

### Services Staying on Indri (Outside K8s)
| Service | Reason |
|---------|--------|
| **Zot Registry** (NEW) | Avoid circular dependency - k8s needs images to start |
| **Prometheus** | Observability backbone must survive k8s failures |
| **Loki** | Log aggregation backbone |
| **Borgmatic** | Backup system |
| **Grafana-alloy** | Metrics/logs collector on host |
| **Plex** | Until Jellyfin replacement |
| **Transmission** | Downloads for kiwix ZIM files |

### Services Moving to K8s
| Service | Complexity | Dependencies |
|---------|------------|--------------|
| Grafana | LOW | Phase 1 |
| Kiwix | LOW | Phase 1 |
| Miniflux | MEDIUM | PostgreSQL |
| devpi | MEDIUM | Registry |
| PostgreSQL | HIGH | Phase 1 |
| Forgejo | HIGH | PostgreSQL |
| Woodpecker CI | MEDIUM | Forgejo |

## Technical Decisions

### Container Registry: Zot
- OCI-native, lightweight
- Native support for proxying multiple registries (Docker Hub, GHCR, Quay)
- Built from source at `~/code/3rd/zot` (not in homebrew)
- Binary: `~/code/3rd/zot/bin/zot-darwin-arm64`
- Config: `~/.config/zot/config.json`
- Data: `~/zot/`

### Minikube Driver: Podman
- Rootless containers for better security
- Lighter than full VM (QEMU)
- Uses existing container ecosystem
- `minikube start --driver=podman --container-runtime=cri-o`

### PostgreSQL: CloudNativePG Operator
- Production-grade operator
- Built-in backup/restore
- Prometheus metrics
- PITR support

### K8s Service Exposure: Tailscale Operator
- `loadBalancerClass: tailscale` on Services
- Automatic TLS and MagicDNS names
- ACL-controlled access

### LaunchAgent Requirements (Critical)
LaunchAgents do NOT get homebrew on PATH. All commands must use **absolute paths**:
- `/Users/erichblume/code/3rd/zot/bin/zot-darwin-arm64` for zot (built from source)
- `/opt/homebrew/opt/mise/bin/mise x --` for mise-managed tools
- `/opt/homebrew/opt/postgresql@18/bin/pg_dump` for postgres tools

This applies to all mcquack LaunchAgents (zot, devpi, kiwix, borgmatic, metrics collectors).
`brew services` handles this automatically but those aren't tracked in ansible.

### Backup Strategy

Borgmatic remains on indri (outside k8s), writing to sifaka NAS via SMB at `/Volumes/backups`. This ensures backups continue even if k8s is down.

| Service | Backup Approach |
|---------|-----------------|
| **Zot Registry** | No backup needed - pull-through cache is re-fetchable, private images rebuilt from source control |
| **Minikube** | No backup of cluster state - declarative manifests in git, can recreate |
| **PostgreSQL (k8s)** | CloudNativePG scheduled backups to sifaka (Phase 1) |
| **Grafana (k8s)** | Dashboards in ansible source control, no runtime backup needed |
| **Miniflux (k8s)** | Database backed up via CloudNativePG |
| **Forgejo (k8s)** | Git repos are distributed, config in ansible; data dir backed up via borgmatic before migration |
| **devpi (k8s)** | Private packages backed up, PyPI cache re-fetchable |
| **Kiwix (k8s)** | ZIM files re-downloadable via torrent, no backup needed |

**Borgmatic config changes:** None required for Phase 0. Future phases may add k8s PV paths if needed.

---

## Critical Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/indri.yml` | Main playbook - add k8s roles, remove migrated services |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Transition services to Tailscale operator |
| `pulumi/policy.hujson` | Add tags: k8s, registry, ci |
| `ansible/roles/borgmatic/defaults/main.yml` | Update PostgreSQL endpoint |
| `mise-tasks/indri-services-check` | Add k8s health checks |

## New Directory Structure

```
ansible/
  k8s/
    operators/
      tailscale-operator.yaml
      cloudnative-pg.yaml
    databases/
      blumeops-pg.yaml
    apps/
      grafana/
      miniflux/
      forgejo/
      devpi/
      kiwix/
      woodpecker/
  roles/
    zot/           # NEW
    podman/        # NEW
    minikube/      # NEW
```

## Risk Mitigation

- **Circular dependency prevention**: Zot registry runs outside k8s
- **Observability**: Prometheus/Loki stay on indri
- **Data loss prevention**: borgmatic + manual backups before each phase
- **Recovery**: Can manually push images, restore from backups

## Container Images (All ARM64)

| Service | Image |
|---------|-------|
| Miniflux | `ghcr.io/miniflux/miniflux:latest` |
| Forgejo | `codeberg.org/forgejo/forgejo:10` |
| Grafana | `grafana/grafana:latest` |
| Kiwix | `ghcr.io/kiwix/kiwix-serve:3.8.1` |
| Woodpecker | `woodpeckerci/woodpecker-server` |

Note: Zot runs as a native binary on indri (built from source at `~/code/3rd/zot`), not as a container.
