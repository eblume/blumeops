New nix-built container `authentik-blueprint-exporter` (homegrown Python
exporter, the transmission-exporter pattern): a standalone Deployment in
the `authentik` namespace that polls each blueprint instance's state
through the read-only `ci-authentik-blueprints` service account and
serves it as Prometheus metrics for the blueprint alerting in
eblume/blumeops#1444, with fixture-based unit tests in CI.
