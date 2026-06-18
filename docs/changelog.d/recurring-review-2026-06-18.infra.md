Daily recurring review pass (2026-06-18):
- Service review of `frigate` (stalest, 86d): already at the latest upstream
  stable (0.17.1 — v0.17.1 is the newest GitHub release), pod healthy and
  serving the API. No upgrade needed; `last-reviewed` bumped in
  `service-versions.yaml`. Noted a high lifetime restart count (206 over 36d,
  last a graceful SIGTERM 3d ago, not an active crash loop) — filed a heph task
  to investigate.
- Doc review of [[port-services-check-alerts]] (never reviewed): corrected the
  stale "blackbox exporter already covers 5 services" claim — the ringtail
  blackbox probe set is currently only `immich`
  (`argocd/manifests/alloy-ringtail/config.alloy`), so re-broadening it is now
  the most impactful next step. All wiki-links verified; set `last-reviewed`.
