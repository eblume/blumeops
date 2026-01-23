# Blumeops Minikube Migration Plan

**Status**: Completed (2026-01-23)

This plan detailed the phased migration of blumeops services from direct hosting on indri (Mac Mini M1) to a minikube cluster. The migration is now complete for all services that will be migrated.

## Final Status

| Phase | Name | Status | Notes |
|-------|------|--------|-------|
| 0 | [Foundation](P0_foundation.complete.md) | ✅ Complete | Container registry (zot) + minikube cluster |
| 1 | [K8s Infrastructure](P1_k8s_infrastructure.complete.md) | ✅ Complete | Tailscale operator, ArgoCD, CloudNativePG, PostgreSQL cluster |
| 2 | [Grafana](P2_grafana.complete.md) | ✅ Complete | Migrated Grafana via ArgoCD |
| 3 | [PostgreSQL](P3_postgresql.complete.md) | ✅ Complete | Data migration to k8s PostgreSQL |
| 4 | [Miniflux](P4_miniflux.complete.md) | ✅ Complete | Migrated Miniflux via ArgoCD |
| 5 | [devpi](P5_devpi.complete.md) | ✅ Complete | Migrated devpi via ArgoCD |
| 5.1 | [Docker Migration](P5.1_docker_migration.complete.md) | ✅ Complete | Switched minikube to docker driver (not QEMU2) |
| 6 | [Kiwix](P6_kiwix.complete.md) | ✅ Complete | Migrated Kiwix + Transmission via ArgoCD |
| 7 | [Forgejo](P7_forgejo.md) | ⏭️ Won't Do | Forgejo stays on indri - see [CI/CD Bootstrap](../../ci-cd-bootstrap/) |
| 8 | [Woodpecker](P8_woodpecker.md) | ⏭️ Won't Do | Replaced by Forgejo Actions - see [CI/CD Bootstrap](../../ci-cd-bootstrap/) |
| 9 | [Cleanup](P9_cleanup.md) | ⏭️ Won't Do | Observability cleanup done separately (2026-01-22) |

## What Was Migrated to K8s

| Service | Status | Notes |
|---------|--------|-------|
| Grafana | ✅ In k8s | Helm chart via ArgoCD |
| PostgreSQL | ✅ In k8s | CloudNativePG operator |
| Miniflux | ✅ In k8s | Using k8s PostgreSQL |
| devpi | ✅ In k8s | Custom container image |
| Kiwix | ✅ In k8s | NFS mount from sifaka |
| Transmission | ✅ In k8s | NFS mount from sifaka |
| Prometheus | ✅ In k8s | Migrated 2026-01-22 |
| Loki | ✅ In k8s | Migrated 2026-01-22 |
| Alloy (k8s) | ✅ In k8s | DaemonSet for pod logs |
| TeslaMate | ✅ In k8s | Added 2026-01-23 |

## What Stays on Indri

| Service | Reason |
|---------|--------|
| **Forgejo** | Critical infrastructure, avoids circular dependency with ArgoCD |
| **Zot Registry** | K8s needs images to start - must be outside k8s |
| **Alloy (host)** | Collects host-level metrics and logs |
| **Borgmatic** | Backup system must survive k8s failures |
| **Plex** | Uses own NAT traversal, not Tailscale |

## Architecture Decisions Made

### Minikube Driver: Docker (not QEMU2/Podman)
- Original plan called for QEMU2, but docker driver proved simpler
- NFS mounts work via Docker NAT through indri's LAN IP
- API server accessible via Tailscale TCP passthrough

### Forgejo: Stays on Indri
- Original P7 planned k8s migration
- Decision changed: Forgejo is critical infrastructure
- Will be built from source via Forgejo Actions CI
- See [CI/CD Bootstrap Plan](../../ci-cd-bootstrap/) for details

### CI/CD: Forgejo Actions (not Woodpecker)
- Original P8 planned Woodpecker deployment
- Decision changed: Use Forgejo's native Actions instead
- Simpler (one less system), GitHub Actions compatible
- See [CI/CD Bootstrap Plan](../../ci-cd-bootstrap/) for details

### Observability: Migrated to K8s
- Original plan kept Prometheus/Loki on indri
- Changed: Migrated both to k8s (2026-01-22)
- Alloy on indri pushes to k8s endpoints
- Alloy DaemonSet in k8s collects pod logs

## Lessons Learned

1. **Docker driver is simpler than QEMU2** - Direct NFS mounts work, no VM complexity
2. **Tailscale operator works well** - Easy service exposure with automatic TLS
3. **CloudNativePG is production-ready** - Good operator, easy backups
4. **Keep critical infra outside k8s** - Forgejo and zot must survive k8s failures
5. **CGO matters on macOS** - Alloy needed CGO=1 for Tailscale DNS resolution
