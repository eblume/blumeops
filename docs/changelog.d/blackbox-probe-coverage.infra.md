Re-broadened the ringtail Alloy blackbox exporter from a single probe (`immich`) to
all 18 in-cluster HTTP services (argocd, authentik, frigate, grafana, homepage,
immich, kiwix, loki, mealie, miniflux, navidrome, ntfy, paperless, prometheus,
shower, teslamate, tempo, transmission). Coverage had collapsed to immich-only
during the minikube retirement, leaving the other services silently unmonitored —
and `mise run services-check` was reporting a green "OK" for 10 of them because its
`ServiceProbeFailure` check passes when no firing instance exists. Each health path
was verified to return 2xx unauthenticated from inside the cluster; `shower` is
probed with its `Host: shower.ops.eblu.me` header and `ollama` is intentionally
excluded (scaled to zero on demand). The single `ServiceProbeFailure` alert covers
every new target automatically via `label_replace` on the `integrations/blackbox/*`
job label, so no new alert rules were needed. `services-check` was updated to mirror
the probe list (no more false OKs) and to check indri/public services (forgejo, zot,
devpi, cv) directly. Also swept stale post-minikube monitoring-host claims from the
docs ([[runbook-service-probe-failure]], [[port-services-check-alerts]],
[[federated-login]], the `tag:loki`/`tag:k8s-api` rows in [[tailscale]], and the
prometheus textfile list).
