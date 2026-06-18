Corrected the `ServiceProbeFailure` runbook's Affected Services table: verified
against live Prometheus that the Alloy blackbox exporter now probes only immich
(`job=integrations/blackbox/immich`), so the table no longer lists the retired
indri-era services (miniflux/kiwix/transmission/devpi/argocd). Added superseded
notes to the historical zot version-sync/tagging design cards
(pin-container-versions, add-container-version-sync-check,
adopt-commit-based-container-tags) pointing at the nix-only reality.
