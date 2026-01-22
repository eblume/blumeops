# Phase 7: Forgejo Migration to Kubernetes

**Goal**: Migrate Forgejo from indri (macOS Homebrew) to Kubernetes via ArgoCD

**Status**: Planning (2026-01-21)

**Prerequisites**: [Phase 6](P6_kiwix.complete.md) complete

---

## Critical Risks & Mitigations

### 1. Circular Dependency (Highest Risk)

ArgoCD pulls manifests from Forgejo. If k8s Forgejo fails, we cannot redeploy it.

**Mitigation**: blumeops is mirrored to `github.com/eblume/blumeops`. DR procedure documented to switch ArgoCD to GitHub temporarily (see Disaster Recovery section).

### 2. Split Hostnames Required

The Tailscale k8s operator [cannot expose both HTTPS and TCP/SSH on the same hostname](https://github.com/tailscale/tailscale/issues/15539). See also [user comment](https://github.com/tailscale/tailscale/issues/15539#issuecomment-3782368432).

**Solution**:
- **HTTPS (web UI)**: `forge.tail8d86e.ts.net` via Tailscale Ingress
- **SSH (git operations)**: `git.tail8d86e.ts.net` via Tailscale LoadBalancer

---

## Current State

### Forgejo on indri

| Component | Location/Details |
|-----------|------------------|
| Data directory | `/opt/homebrew/var/forgejo/` (~426MB) |
| SQLite database | `/opt/homebrew/var/forgejo/data/forgejo.db` (4.1MB) |
| Git repositories | `/opt/homebrew/var/forgejo/data/forgejo-repositories/` (~418MB) |
| Configuration | `/opt/homebrew/var/forgejo/custom/conf/app.ini` (contains secrets) |
| HTTP port | 3001 (localhost) |
| SSH port | 2200 (localhost) |
| Tailscale | `svc:forge` with tcp:22→2200 and https:443→3001 |
| Backup | borgmatic backs up to sifaka |

### Hosted Repositories (8 total)

- blumeops (mirrored to GitHub)
- cloudnative-pg-charts
- csi-driver-smb
- devpi
- dotfiles
- grafana-helm-charts
- mcquack
- zot

---

## Architecture Decision: Helm Chart via ArgoCD

Following established pattern from cloudnative-pg and grafana:
1. Mirror `https://code.forgejo.org/forgejo-helm/forgejo-helm` to forge
2. ArgoCD Application with multi-source (chart + values)
3. Values file in `argocd/manifests/forgejo/values.yaml`

---

## All `forge` References Requiring Update

### SSH URLs (change to `git.tail8d86e.ts.net:22`)

| File | Current | After |
|------|---------|-------|
| `argocd/apps/apps.yaml` | `ssh://forgejo@indri.tail8d86e.ts.net:2200/...` | `ssh://forgejo@git.tail8d86e.ts.net/...` |
| `argocd/apps/argocd.yaml` | same | same |
| `argocd/apps/blumeops-pg.yaml` | same | same |
| `argocd/apps/cloudnative-pg.yaml` | same | same |
| `argocd/apps/devpi.yaml` | same | same |
| `argocd/apps/grafana.yaml` | same | same |
| `argocd/apps/grafana-config.yaml` | same | same |
| `argocd/apps/kiwix.yaml` | same | same |
| `argocd/apps/miniflux.yaml` | same | same |
| `argocd/apps/tailscale-operator.yaml` | same | same |
| `argocd/apps/torrent.yaml` | same | same |
| `argocd/manifests/argocd/repo-forge-secret.yaml.tpl` | `ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/` | `ssh://forgejo@git.tail8d86e.ts.net/eblume/` |
| `ansible/group_vars/all.yml` | `ssh://forgejo@forge.tail8d86e.ts.net/...` | `ssh://forgejo@git.tail8d86e.ts.net/...` |

### SSH Known Hosts (add `git.tail8d86e.ts.net`)

| File | Change |
|------|--------|
| `argocd/manifests/argocd/argocd-ssh-known-hosts-cm.yaml` | Add `git.tail8d86e.ts.net ssh-ed25519 AAAA...` |

### HTTPS URLs (stay as `forge.tail8d86e.ts.net`)

These remain unchanged:
- `CLAUDE.md:135` - Mirror location
- `mise-tasks/pr-comments:23` - Forge API base
- `mise-tasks/indri-services-check:65` - HTTP health check (update to check k8s)

### Ansible/Indri Cleanup (remove after migration)

| File | Action |
|------|--------|
| `ansible/playbooks/indri.yml:36-37` | Remove forgejo role |
| `ansible/roles/tailscale_serve/defaults/main.yml:6` | Remove `svc:forge` entry |
| `ansible/roles/alloy/defaults/main.yml:31-32` | Remove forgejo log collection |
| `ansible/roles/borgmatic/defaults/main.yml:17` | Update backup path |

### Tailscale/Pulumi (update after hostname cutover)

| File | Change |
|------|--------|
| `argocd/manifests/tailscale-operator/egress-forge.yaml` | Delete (no longer needed) |
| `pulumi/policy.hujson` | Update `tag:forge` ACLs for k8s source |

---

## Pre-Migration Checklist

- [ ] GitHub mirror verified current
- [ ] Full borgmatic backup completed and verified
- [ ] Manual backup of `/opt/homebrew/var/forgejo` on indri
- [ ] Document all SSH deploy keys and webhooks
- [ ] **User action**: Mirror forgejo-helm chart to forge
- [ ] Extract secrets from app.ini to 1Password:
  - `INTERNAL_TOKEN`
  - `SECRET_KEY`
  - `JWT_SECRET`
  - Any OAuth/webhook secrets

---

## Steps

### Phase A: Create k8s Manifests

**New Files:**
```
argocd/apps/forgejo.yaml                    # ArgoCD Application (multi-source Helm)
argocd/manifests/forgejo/values.yaml        # Helm chart values
argocd/manifests/forgejo/kustomization.yaml # Kustomize config
argocd/manifests/forgejo/pvc.yaml           # 10Gi PersistentVolumeClaim
argocd/manifests/forgejo/secret-app.yaml.tpl # Secrets from 1Password
```

**Key values.yaml settings:**
```yaml
service:
  ssh:
    type: LoadBalancer
    loadBalancerClass: tailscale
    port: 22
    annotations:
      tailscale.com/hostname: "git-1"  # Test hostname first

ingress:
  enabled: true
  className: tailscale
  hosts:
    - host: forge-1  # Test hostname first

gitea:
  config:
    server:
      DOMAIN: forge-1.tail8d86e.ts.net
      ROOT_URL: https://forge-1.tail8d86e.ts.net/
      SSH_DOMAIN: git-1.tail8d86e.ts.net
      SSH_PORT: 22
    database:
      DB_TYPE: sqlite3
      PATH: /data/forgejo.db
```

---

### Phase B: Deploy to Test Hostnames

1. Create feature branch, push to forge
2. Sync ArgoCD apps: `argocd app sync apps`
3. Point forgejo app to feature branch: `argocd app set forgejo --revision feature/p7-forgejo`
4. Sync forgejo app: `argocd app sync forgejo`
5. Verify pods running (empty data initially)

---

### Phase C: Data Migration (~10 min downtime)

1. **Stop indri Forgejo**
   ```bash
   ssh indri 'brew services stop forgejo'
   ```

2. **Copy data** (option A: rsync via NFS staging)
   ```bash
   ssh indri 'rsync -avP /opt/homebrew/var/forgejo/ sifaka:/volume1/forgejo-migration/'
   ```

3. **Copy to PVC and fix permissions**
   ```bash
   kubectl exec -n forgejo deployment/forgejo -- rsync -avP /staging/ /data/
   kubectl exec -n forgejo deployment/forgejo -- chown -R 1000:1000 /data
   ```

4. **Restart Forgejo**
   ```bash
   kubectl rollout restart deployment/forgejo -n forgejo
   ```

---

### Phase D: Validation (Critical)

- [ ] Web UI accessible at `forge-1.tail8d86e.ts.net`
- [ ] SSH works: `ssh -T forgejo@git-1.tail8d86e.ts.net`
- [ ] All 8 repos visible and accessible
- [ ] Git clone works
- [ ] Git push works (test on non-critical repo)
- [ ] eblume user preserved with correct permissions
- [ ] PR history intact
- [ ] Webhooks functioning
- [ ] GitHub mirror push still works

---

### Phase E: Hostname Cutover

1. **Clear indri Tailscale serve**
   ```bash
   ssh indri 'tailscale serve clear svc:forge'
   ```

2. **User action**: Delete `svc:forge` and `forge-1` devices from Tailscale admin

3. **Update manifests**: Change `forge-1` → `forge`, `git-1` → `git`

4. **Sync ArgoCD**

5. **Verify hostnames claimed**
   ```bash
   curl https://forge.tail8d86e.ts.net/api/v1/version
   ssh -T forgejo@git.tail8d86e.ts.net
   ```

---

### Phase F: Update ArgoCD to Use New Forgejo

1. **Get SSH host key from k8s Forgejo**
   ```bash
   kubectl exec -n forgejo deployment/forgejo -- cat /data/ssh/ssh_host_ed25519_key.pub
   ```

2. **Update known_hosts ConfigMap** with `git.tail8d86e.ts.net` key

3. **Update repo-creds-forge secret** (manual kubectl commands)

4. **Update all ArgoCD Application manifests** with new repoURL

5. **Delete egress-forge.yaml** (no longer needed)

6. **Sync ArgoCD** and verify all apps sync successfully

---

### Phase G: Update Local Git Remotes

```bash
cd ~/code/personal/blumeops
git remote set-url origin ssh://forgejo@git.tail8d86e.ts.net/eblume/blumeops.git
# Repeat for all 8 repos
```

---

### Phase H: Cleanup

1. Remove forgejo role from `ansible/playbooks/indri.yml`
2. Remove `svc:forge` from `ansible/roles/tailscale_serve/defaults/main.yml`
3. Remove forgejo log collection from `ansible/roles/alloy/defaults/main.yml`
4. Delete `argocd/manifests/tailscale-operator/egress-forge.yaml`
5. Update `mise-tasks/indri-services-check`
6. Run ansible to clean up indri: `mise run provision-indri -- --tags tailscale-serve,alloy`
7. Update zk documentation (forgejo, argocd, blumeops cards)
8. Merge PR
9. Reset ArgoCD to main

---

## Disaster Recovery Procedure

**Add to [[forgejo]] zk card:**

### When Forgejo is Unavailable

1. **Add GitHub repository to ArgoCD**
   ```bash
   argocd repo add https://github.com/eblume/blumeops.git \
     --username eblume \
     --password $(op read "op://<vault>/<item>/github-pat")
   ```

2. **Point critical apps to GitHub**
   ```bash
   argocd app set apps --repo https://github.com/eblume/blumeops.git
   argocd app set forgejo --repo https://github.com/eblume/blumeops.git
   argocd app sync forgejo
   ```

3. **Fix Forgejo** (restore from backup, fix config, etc.)

4. **Verify Forgejo is healthy**
   ```bash
   curl https://forge.tail8d86e.ts.net/api/v1/version
   ssh -T forgejo@git.tail8d86e.ts.net
   ```

5. **Switch back to Forgejo**
   ```bash
   argocd app set apps --repo ssh://forgejo@git.tail8d86e.ts.net/eblume/blumeops.git
   argocd app set forgejo --repo ssh://forgejo@git.tail8d86e.ts.net/eblume/blumeops.git
   argocd app sync apps
   argocd repo rm https://github.com/eblume/blumeops.git
   ```

---

## Files Summary

### New Files

| Path | Purpose |
|------|---------|
| `argocd/apps/forgejo.yaml` | ArgoCD Application (multi-source Helm) |
| `argocd/manifests/forgejo/values.yaml` | Helm chart values |
| `argocd/manifests/forgejo/kustomization.yaml` | Kustomize config |
| `argocd/manifests/forgejo/pvc.yaml` | 10Gi PersistentVolumeClaim |
| `argocd/manifests/forgejo/secret-app.yaml.tpl` | Secrets template |

### Modified Files

| Path | Change |
|------|--------|
| All `argocd/apps/*.yaml` | Update repoURL to `git.tail8d86e.ts.net` |
| `argocd/manifests/argocd/argocd-ssh-known-hosts-cm.yaml` | Add `git.tail8d86e.ts.net` |
| `argocd/manifests/argocd/repo-forge-secret.yaml.tpl` | Update URL |
| `ansible/playbooks/indri.yml` | Remove forgejo role |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Remove `svc:forge` |
| `ansible/roles/alloy/defaults/main.yml` | Remove forgejo logs |

### Files to Delete

| Path | Reason |
|------|--------|
| `argocd/manifests/tailscale-operator/egress-forge.yaml` | No longer needed |

---

## Rollback

If migration fails at any point:

1. **Delete k8s resources**
   ```bash
   argocd app delete forgejo --cascade
   kubectl delete namespace forgejo
   ```

2. **Restart indri Forgejo**
   ```bash
   ssh indri 'brew services start forgejo'
   ```

3. **Re-enable Tailscale serve**
   ```bash
   mise run provision-indri -- --tags tailscale-serve
   ```

4. **Revert ArgoCD apps to indri URLs** (if changed)

---

## Verification Checklist

- [ ] GitHub mirror verified current
- [ ] Helm chart mirrored to forge
- [ ] Secrets extracted to 1Password
- [ ] k8s Forgejo pod running
- [ ] All 8 repos accessible
- [ ] SSH clone/push works via `git.tail8d86e.ts.net`
- [ ] HTTPS works via `forge.tail8d86e.ts.net`
- [ ] ArgoCD syncs from new URL
- [ ] All local remotes updated
- [ ] Indri cleanup complete
- [ ] zk docs updated
- [ ] DR procedure documented in [[forgejo]] card
