---
title: "Runbook: PostgreSQL Cluster Unhealthy"
modified: 2026-08-14
last-reviewed: 2026-08-14
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: PostgreSQL Cluster Unhealthy

**Alert name:** `PostgresClusterUnhealthy`

The CNPG collector's metrics endpoint stopped answering — `cnpg_collector_up < 1`
for 3m, with `noDataState: Alerting`.

## First: which cluster?

The alert covers **two** CNPG clusters, both in the `databases` namespace on
ringtail's k3s. The scrape job (`cnpg-postgres`) sets `instance` per target and
hardcodes `cluster: ringtail` for every metric on this Prometheus, so
`instance` is the label that names the cluster:

```fish
mise run agent-metrics 'cnpg_collector_up'
```

That works from anywhere, agent pods included, and is the fastest way to tell
one cluster's outage from the other's — or from an outage of the scrape itself.

| `instance` | Cluster | Databases |
|------------|---------|-----------|
| `blumeops-pg` | `blumeops-pg` | paperless (bootstrap), teslamate, miniflux, authentik, plus the `eblume` admin and `borgmatic` backup roles |
| `immich-pg` | `immich-pg` | immich (VectorChord image, not the stock operand) |

**Both instances silent at once is a scrape problem, not two databases dying
together.** `noDataState: Alerting` means this rule fires when the series is
absent, so a broken `prometheus-ringtail` or a deleted metrics Service looks
identical to a down cluster. Check that Prometheus itself is up before
declaring a database outage.

## Affected services

`blumeops-pg` down: Paperless, TeslaMate, Miniflux, Authentik — **and Authentik
being down takes SSO with it**, so Grafana and ArgoCD logins fail too. The
Grafana TeslaMate datasource and borgmatic's nightly `pg_dump` streams
([[backups]]) also read from it.

`immich-pg` down: Immich only.

## Diagnostic steps

1. **Cluster and pod status**:

   ```fish
   kubectl get cluster -n databases --context=k3s-ringtail
   kubectl get pods -n databases --context=k3s-ringtail
   ```

2. **Pod logs** (swap the cluster name for the `instance` from the alert):

   ```fish
   kubectl logs -n databases -l cnpg.io/cluster=blumeops-pg --context=k3s-ringtail --tail=30
   ```

3. **Reachability over the tailnet.** Each cluster is behind its own Caddy L4
   port on indri — there is no `pg.ops.eblu.me:5432`; that route retired with
   the minikube cluster ([[retire-minikube]] phase 5):

   ```fish
   pg_isready -h pg.ops.eblu.me -p 5434   # blumeops-pg
   pg_isready -h pg.ops.eblu.me -p 5433   # immich-pg
   ```

   The ports are declared in `caddy_l4_routes`
   (`ansible/roles/caddy/defaults/main.yml`). A failure here with healthy pods
   is a Caddy or tailscale-LoadBalancer problem, not a database one — the
   backends are `blumeops-pg-ringtail.tail8d86e.ts.net` and
   `immich-pg.tail8d86e.ts.net`. For an interactive session see
   [[connect-to-postgres]].

4. **PVC storage** — each cluster requests 10Gi on `local-path`:

   ```fish
   kubectl get pvc -n databases --context=k3s-ringtail
   kubectl exec -n databases blumeops-pg-1 --context=k3s-ringtail -- df -h /var/lib/postgresql/data
   ```

## Common causes

- **Pod crash** — OOM, disk full, or a config error. Both clusters run
  `instances: 1`, so there is no replica to fail over to: a crash is an outage
  until the pod comes back.
- **PVC full** — `local-path` volumes do not grow on their own.
- **Node memory pressure on ringtail** — the k3s node hosts Immich's ML stack
  and Ollama alongside these; an evicted CNPG pod shows up here first.
- **Scrape broken** — see the NoData note above.
- **Caddy L4 route** — affects clients, not the cluster; the alert stays clear
  because Prometheus scrapes in-cluster.

## Silencing

For planned database maintenance:

1. Grafana → Alerting → Silences → Create Silence
2. Match `alertname = PostgresClusterUnhealthy`, and add
   `instance = blumeops-pg` (or `immich-pg`) to silence only the one you are
   working on.

## Related

- [[postgresql]] — CNPG cluster reference
- [[connect-to-postgres]] — getting a psql session
- [[backups]] — what borgmatic pulls from each cluster
- [[deploy-infra-alerting]] — alerting pipeline overview
