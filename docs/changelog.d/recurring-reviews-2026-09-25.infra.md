Bump the Nix-built Prometheus image (containers/prometheus) from v3.12.0 to
v3.14.0, the latest upstream release (2026-08-17). v3.13.x carried fixes
including GO-2026-5841/GO-2026-6303 dependency security fixes. No v3.13/v3.14
`[CHANGE]` item is breaking for a stock single-instance scrape/remote_write
deployment (stats query-param deprecation is a warning only until the next
major; Hetzner SD label drop and default PromQL duration expressions are
behavior-neutral here), so no prometheus.yml change is needed. The
v3.14.0 fetchgit path hash is pinned in-tree; npmDepsHash and vendorHash are
TOFU (fakeHash), pinned from the Build Container check that reports them.
The prometheus-ringtail image tag pin lands in a follow-up PR (opened by
horkos) once the build is green. Part of #1282.
