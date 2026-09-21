---
title: "Runbook: Service Probe Failure"
modified: 2026-09-21
last-reviewed: 2026-09-21
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Service Probe Failure

**Alert name:** `ServiceProbeFailure`

A blackbox HTTP health check has failed for 2+ minutes, meaning a service is not responding to its health endpoint.

## Affected Services

This alert covers the HTTP services probed by the Alloy blackbox exporter on
ringtail's k3s cluster, in two groups. Both groups are defined in
`argocd/manifests/alloy-ringtail/config.alloy` (`prometheus.exporter.blackbox`
components), each probe lands under the `integrations/blackbox/<name>` job, and
the single `label_replace` rule covers any of them.

### In-cluster services

| Service | Health Endpoint |
|---------|----------------|
| argocd | `/healthz` |
| authentik | `/-/health/live/` |
| frigate | `/api/version` |
| grafana | `/api/health` |
| homepage | `/` |
| immich | `/api/server/ping` |
| kiwix | `/` |
| loki | `/ready` |
| mealie | `/api/app/about` |
| miniflux | `/healthcheck` |
| navidrome | `/ping` |
| ntfy | `/v1/health` |
| paperless | `/accounts/login/` |
| prometheus | `/-/healthy` |
| teslamate | `/` |
| tempo | `/ready` |
| transmission | `/transmission/web/` |

`ollama` is **not** probed: it is scaled to zero unless explicitly needed, so a
probe would fire this alert permanently.

### Public services (Caddy on indri)

These backends run natively on indri behind its Caddy front; the probe hits
Caddy over the tailnet, so a failure here also witnesses the front itself.
They have no pods — the k3s diagnostic steps below do not apply; triage them
with the signatures in the next section instead.

| Service | Health Endpoint |
|---------|----------------|
| cv | `/` |
| docs | `/` |
| forge | `/` |
| heph | `/` |
| jellyfin | `/` (302 → `/web/`; the prober follows redirects) |
| pypi | `/` |
| registry | `/` |

`mise run services-check` (human task, run from gilbert) still performs a
fuller direct check of the indri-native services.

The failing service is identified by the `service` label in the alert, extracted
from the `job` label (e.g. `integrations/blackbox/immich` → `immich`). To add a
service to this alert, add a `target` block to the matching blackbox exporter
component in the Alloy config (`services` for in-cluster, `public` for the
Caddy-fronted hosts) — no new alert rule is needed, the single `label_replace`
rule covers any `integrations/blackbox/*` job.

## Triage: front up vs front down (public services)

For the public (indri-local) services, the probe metrics separate a backend
outage from a front outage — the signature the forgejo unit flip drill established (#1210):

- **`probe_success 0` with `probe_http_status 502`** — Caddy is up but the
  backend on indri is down. Check that backend process on indri
  (`ssh indri 'launchctl list | grep <svc>'` or `mise run services-check` from
  gilbert). cv and docs are Caddy-served static sites with no backend, so for
  them the 502 means the served files themselves are gone.
- **`probe_success 0` with no `probe_http_status`** — the connection to Caddy
  itself failed. The whole public surface is dark: indri asleep, Caddy down,
  or the tailnet path broken. This is what the 2026-09-16 indri sleep episode
  ([[indri]]) looked like with no Prometheus witness.

Check either with
`mise run agent-metrics 'probe_http_status{job="integrations/blackbox/forge"}'`
(or any other public job). An empty result is the refused-connection
signature — provided `probe_success` has data in the same window, so the
result isn't just the probe pipeline itself having gone dark.

## Diagnostic Steps

These k3s steps apply to the in-cluster services. For the public services, use
the triage signatures above.

1. **Check which service is down** — the alert label `service` tells you. You can also run:
   ```fish
   kubectl get pods -n <namespace> --context=k3s-ringtail
   ```

2. **Check pod status** — look for CrashLoopBackOff, OOMKilled, or pending pods:
   ```fish
   kubectl describe pod -n <namespace> <pod-name> --context=k3s-ringtail
   ```

3. **Check pod logs**:
   ```fish
   kubectl logs -n <namespace> <pod-name> --context=k3s-ringtail --tail=50
   ```

4. **Check if the cluster itself is healthy**:
   ```fish
   kubectl get nodes --context=k3s-ringtail
   ssh ringtail 'systemctl status k3s'
   ```

5. **Check NFS mounts** (frigate, immich, kiwix, navidrome, paperless,
   and transmission depend on sifaka NFS, mounted into pods via NFS PVs — see
   [[sifaka-nfs-from-ringtail]]). A lost mount shows up as pod mount errors:
   ```fish
   kubectl describe pod -n <namespace> <pod-name> --context=k3s-ringtail
   ```

## Common Causes

- **Pod crashed** — check logs, restart with `kubectl delete pod`
- **NFS mount lost** — sifaka offline or its NFS export unreachable. Check pod events for mount errors; see [[sifaka-nfs-from-ringtail]]
- **Resource exhaustion** — look for `OOMKilled` in the pod events (step 2).
  `kubectl top` does not work here: ringtail's k3s runs with
  `--disable=metrics-server`, so the Metrics API does not exist. For node-level
  numbers see [[runbook-pod-not-ready]] (Prometheus queries, `kubectl
  describe node`)
- **k3s down** — `ssh ringtail 'systemctl status k3s'`, restart if needed

## Silencing

For planned maintenance, silence this alert in Grafana:
1. Go to Alerting → Silences → Create Silence
2. Match label `alertname = ServiceProbeFailure`
3. Optionally match `service = <specific-service>` to silence only one
4. Set duration for your maintenance window

## Related

- [[runbook-pod-not-ready]] — Sibling runbook; has the working Prometheus
  resource-pressure queries
- [[deploy-infra-alerting]] — Alerting pipeline overview
- [[configure-grafana-alerting-pipeline]] — Pipeline configuration
