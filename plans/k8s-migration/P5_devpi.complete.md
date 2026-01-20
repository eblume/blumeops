# Phase 5: devpi Migration to Kubernetes

**Goal**: Migrate devpi PyPI caching proxy from indri to k8s

**Status**: Complete (2026-01-20)

**Prerequisites**: [Phase 4](P4_miniflux.complete.md) complete

---

## Summary

Successfully migrated devpi from mcquack LaunchAgent on indri to Kubernetes:
- Custom container image with devpi-server + devpi-web + auto-init startup script
- StatefulSet with 50Gi PVC for data persistence
- Tailscale Ingress at `pypi.tail8d86e.ts.net`
- Root password from 1Password secret, auto-initialized on first run
- Verified pip caching proxy and mcquack package upload

---

## Key Learnings

### Registry Mirror Configuration
- Minikube's CRI-O can't resolve Tailscale hostnames directly
- Added registry mirror config to redirect `registry.tail8d86e.ts.net` → `host.containers.internal:5050`
- Also added direct insecure registry entry for `host.containers.internal:5050`
- Config in `ansible/roles/minikube/files/zot-mirror.conf`

### Memory Requirements
- devpi-web's Whoosh search indexer needs significant memory during PyPI index build
- Initial 512Mi limit caused OOMKills
- Solution: High limit (2Gi) with low request (256Mi) - memory reclaimed after indexing

### Environment Variable Conflicts
- Kubernetes auto-sets `DEVPI_PORT` for service discovery
- Conflicted with our port config - renamed to `DEVPI_LISTEN_PORT`

### Tailscale Serve Cleanup
- Use `tailscale serve status --json` to see entries (non-JSON output can be empty)
- Use `tailscale serve clear svc:<name>` to remove entries

### ArgoCD Workflow
- Changed `apps` to manual sync (was auto-sync with prune)
- Workflow: sync apps → set revision to feature branch → sync service → test → reset to main after merge

---

## Verification Checklist

- [x] devpi pod healthy in k8s
- [x] https://pypi.tail8d86e.ts.net accessible
- [x] Web interface shows root/pypi index
- [x] `pip install <package>` works through proxy
- [x] mcquack v1.0.0 uploaded to eblume/dev
- [x] `pip install --index-url https://pypi.tail8d86e.ts.net/eblume/dev/+simple/ mcquack` works
- [x] Old devpi service removed from indri
- [ ] zk documentation updated (deferred - no existing devpi card)

---

## Files Changed

### New Files
| Path | Purpose |
|------|---------|
| `argocd/apps/devpi.yaml` | ArgoCD Application definition |
| `argocd/manifests/devpi/Dockerfile` | Container image with startup script |
| `argocd/manifests/devpi/start.sh` | Auto-init startup script |
| `argocd/manifests/devpi/statefulset.yaml` | StatefulSet with PVC |
| `argocd/manifests/devpi/service.yaml` | ClusterIP Service |
| `argocd/manifests/devpi/ingress-tailscale.yaml` | Tailscale Ingress |
| `argocd/manifests/devpi/kustomization.yaml` | Kustomize configuration |
| `argocd/manifests/devpi/secret-root.yaml.tpl` | 1Password secret template |
| `argocd/manifests/devpi/README.md` | Setup documentation |

### Modified Files
| Path | Change |
|------|--------|
| `CLAUDE.md` | Added k8s/ArgoCD workflow documentation |
| `ansible/playbooks/indri.yml` | Removed devpi and devpi_metrics roles |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Removed svc:pypi |
| `ansible/roles/alloy/defaults/main.yml` | Removed devpi log collection |
| `ansible/roles/borgmatic/defaults/main.yml` | Removed devpi backup paths |
| `ansible/roles/minikube/files/zot-mirror.conf` | Added registry mirror for Tailscale hostname |
| `argocd/apps/apps.yaml` | Changed to manual sync policy |

### Roles Kept (not deleted)
- `ansible/roles/devpi/` - Kept for reference
- `ansible/roles/devpi_metrics/` - Kept for reference

---

## Post-Merge Cleanup

After PR merge, reset ArgoCD apps to main:
```fish
argocd app set apps --revision main
argocd app sync apps
argocd app set devpi --revision main
argocd app sync devpi
```
