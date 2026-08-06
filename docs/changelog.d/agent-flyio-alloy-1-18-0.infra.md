Fly proxy: Grafana Alloy v1.17.1 → v1.18.0. The v1.18.0 breaking changes are
confined to `otelcol.*` components and `fly/alloy.river` uses none of them —
only `local.file_match`, `loki.*`, and `prometheus.*` — so the upgrade is a
no-op for our config. Deferred at the 2026-07-20 service review purely because
the release was hours old and this is the public-facing edge; v1.18.0 has since
stood 17 days as the head of the train with no patch behind it.
