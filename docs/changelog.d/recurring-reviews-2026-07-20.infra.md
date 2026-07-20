Service review: upgraded the Fly proxy's Grafana Alloy sidecar binary from
v1.17.0 to v1.17.1 (digest-pinned), and corrected the stale `flyio-alloy`
tracking entry in `service-versions.yaml`, which claimed v1.14.1 while the
Dockerfile had been on v1.17.0.
