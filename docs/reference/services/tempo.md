---
title: Tempo
modified: 2026-03-05
tags:
  - service
  - observability
---

# Grafana Tempo

Distributed tracing backend for BlumeOps infrastructure. Receives traces via OTLP, stores them locally, and generates RED metrics (rate, error, duration) for [[prometheus]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://tempo.ops.eblu.me (when Caddy route added) |
| **Tailscale URL** | https://tempo.tail8d86e.ts.net |
| **OTLP Endpoint** | https://tempo-otlp.tail8d86e.ts.net |
| **Namespace** | `monitoring` |
| **Image** | `grafana/tempo:2.10.1` |
| **Storage** | 10Gi PVC (local filesystem) |
| **Retention** | 7 days |

## Architecture

- Single-node deployment with local filesystem storage
- OTLP receivers: gRPC (4317) and HTTP (4318)
- `metrics_generator` produces span-metrics and service-graphs, remote-written to [[prometheus]]
- Queried via [[grafana]] Tempo datasource
- Two Tailscale Ingresses: one for query API (3200), one for OTLP HTTP receiver (4318)

## Trace Sources

**From ringtail (via Beyla eBPF in Alloy):**

| Service | Protocol | Coverage |
|---------|----------|----------|
| [[frigate]] | HTTP REST | Request rate, error rate, latency, trace spans |
| [[ntfy]] | HTTP | Same |
| [[ollama]] | HTTP REST | Same (model inference latency) |
| [[immich]] | HTTP REST | Same |

Beyla auto-instruments HTTP services via eBPF kernel hooks — no code changes needed. MQTT (Mosquitto) is not instrumented (no eBPF parser for MQTT).

**Future: SDK instrumentation**
Services with OTel SDK support (e.g., Hermes) can send traces directly to the OTLP endpoint for deeper internal spans (DB queries, business logic) alongside eBPF envelope traces.

## Storage Monitoring

Tempo exposes `tempodb_backend_bytes_total` via its `/metrics` endpoint (scraped by [[prometheus]]). To check storage utilization against the 10Gi PVC:

```promql
tempodb_backend_bytes_total / 10737418240 * 100
```

Full PVC-level monitoring (via kubelet volume stats) is not yet available — see backlog.

## Grafana Integration

- **Tempo datasource** with trace-to-log and trace-to-metrics correlation
- **Service map** and **node graph** visualization
- **Loki derived fields** link trace IDs in logs back to Tempo

## Related

- [[alloy|Alloy]] - Trace collector (Beyla eBPF on ringtail)
- [[prometheus]] - Receives span-metrics from Tempo
- [[loki]] - Log correlation via trace IDs
- [[grafana]] - Trace visualization
