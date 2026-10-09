Egress-gateway `ts` sidecar now serves containerboot's /healthz (TS_ENABLE_HEALTH_CHECK, bound [::]:9002) and carries an httpGet readiness probe on it, so the pod is Ready only once tailscaled is logged in with tailnet IPs — a rejected Tailscale auth key can no longer produce a Ready pod and take the tailnet identity off the old gateway pod during a rollout.
Part of eblume/blumeops#1487.
