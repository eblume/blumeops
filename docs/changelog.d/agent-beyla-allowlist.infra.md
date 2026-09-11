alloy-tracing-ringtail: re-enable Beyla eBPF instrumentation after the
beyla v3.33.0 bump (OBI uprobe-preemption fix). The old `open_ports =
"80-9999"` catch-all is replaced by a namespace allowlist (the 16 app
namespaces, containers_only; 1password intentionally excluded), with the
attach-time exe_path glob backstops kept. OTEL_EBPF_LOG_LEVEL=debug is set
for the diagnostic rollout to log per-pid exclusion decisions; it is
dropped once the allowlist is confirmed.
