# Phase 7: Forgejo Migration (Highest Risk)

**Goal**: Migrate Forgejo to k8s

**Status**: Pending

**Prerequisites**: [Phase 6](P6_kiwix.md) complete

---

## Pre-Migration Checklist

- [ ] Full borgmatic backup verified
- [ ] Manual backup of `/opt/homebrew/var/forgejo`
- [ ] Document SSH keys and webhooks

---

## Steps

### 1. Deploy Forgejo via Helm

```bash
helm install forgejo forgejo/forgejo \
  --namespace forgejo --create-namespace
```

---

### 2. Migrate data

- Stop brew forgejo
- Copy data to PVC
- Start k8s forgejo

---

### 3. Configure Tailscale services

- HTTPS 443 via LoadBalancer
- SSH port 22 (TCP proxy)

---

### 4. Verify all repositories accessible

---

## Rollback

Restore brew forgejo and tailscale serve config
