# Phase 6: Kiwix Migration

**Goal**: Migrate kiwix-serve to k8s

**Status**: Pending

**Prerequisites**: [Phase 5](P5_devpi.md) complete

---

## Steps

### 1. Create NFS/hostPath PV for ZIM files

- Point to transmission download directory
- ReadOnlyMany access

---

### 2. Deploy Kiwix

```yaml
image: ghcr.io/kiwix/kiwix-serve:3.8.1
args: ["/data/*.zim"]
```

---

### 3. Configure Tailscale LoadBalancer

Tag: `svc:kiwix`

---

### 4. Stop mcquack kiwix-serve
