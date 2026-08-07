The observability replication tutorial had the three pillars wrong: it listed
metrics, logs and **dashboards**, omitting traces entirely — despite Tempo,
Beyla eBPF auto-instrumentation and full trace↔log↔metric correlation all being
deployed. Corrected to metrics/logs/traces with collection and presentation as
supporting layers, and added the two steps that were missing: deploying Tempo,
and the privileged `alloy-tracing` DaemonSet that produces spans without
instrumenting any application.
