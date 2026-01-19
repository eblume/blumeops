# Phase 2: Grafana Migration (Pilot)

**Goal**: Migrate Grafana as lowest-risk pilot service

**Status**: Pending

**Prerequisites**: [Phase 1](P1_k8s_infrastructure.md) complete

---

## Steps

### 1. Deploy Grafana via Helm

- Copy datasource config from existing role
- Copy dashboards from `ansible/roles/grafana/files/dashboards/`
- Point to indri Prometheus/Loki (http://indri:9090, http://indri:3100)

---

### 2. Configure Tailscale LoadBalancer

```yaml
service:
  type: LoadBalancer
  loadBalancerClass: tailscale
```

---

### 3. Verify all dashboards work

---

### 4. Update tailscale_serve

Remove grafana entry from `ansible/roles/tailscale_serve/defaults/main.yml`

---

### 5. Stop brew grafana

```bash
brew services stop grafana
```

---

## Verification

- https://grafana.tail8d86e.ts.net loads
- All dashboards functional
