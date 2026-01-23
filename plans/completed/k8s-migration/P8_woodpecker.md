# Phase 8: CI/CD (Woodpecker)

**Goal**: Deploy Woodpecker CI integrated with Forgejo

**Status**: Pending

**Prerequisites**: [Phase 7](P7_forgejo.md) complete

---

## Steps

### 1. Create Forgejo OAuth application

- Callback: https://ci.tail8d86e.ts.net/authorize
- Store in 1Password

---

### 2. Deploy Woodpecker Server + Agent

---

### 3. Configure Tailscale LoadBalancer

Tag: `svc:ci`

---

### 4. Test pipeline

Create `.woodpecker.yaml` in test repo
