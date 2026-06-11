Upgraded Prometheus v3.10.0 → v3.12.0. Picks up fixes for stored XSS
(CVE-2026-40179, GHSA-fw8g-cg8f-9j28) and remote-write/remote-read snappy
decompression DoS (CVE-2026-42154), plus TSDB performance improvements. No
breaking changes affect our deployment.
