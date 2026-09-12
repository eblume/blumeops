alloy-tracing-ringtail: the diagnostic-roll log-level env was
OTEL_EBPF_LOG_LEVEL, which beyla v3.33 does not read — the binary takes its
level from BEYLA_LOG_LEVEL (yaml log_level). Rename the env so the
per-pid exclusion decisions actually land in the logs.
