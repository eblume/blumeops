Daily recurring review pass (2026-06-17):
- ntfy upgraded v2.19.2 → v2.24.0 (service review). Custom nix image rebuilt
  from the forge mirror; no breaking config changes across v2.20–v2.24 (S3
  attachment store, verified-email recipients, ACL access cache, SQLite
  case-sensitive ACL fix, PWA token auto-extend). Image tag bumped in
  `argocd/manifests/ntfy/kustomization.yaml`.
- Doc review of [[first-alert-and-runbook]]: marked the alerting POC as
  complete/deployed and corrected the stale "5 probed services" claim —
  blackbox coverage is currently only `immich` (see [[port-services-check-alerts]]
  to re-expand).
