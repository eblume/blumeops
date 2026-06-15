Doc review: [[configure-grafana-alerting-pipeline]] accuracy pass — corrected
the stale "Grafana and ntfy are on different clusters" rationale. Both now run
on ringtail's k3s since the minikube retirement, so the cross-cluster Caddy
workaround is no longer load-bearing (cluster-internal ntfy DNS is now a viable
future simplification).
