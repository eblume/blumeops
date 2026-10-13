authentik blueprint-state exporter wired into the `authentik` app: standalone
Deployment + Service (image pinned to `v0.1.0-e0539e2-nix`), an alloy-ringtail
scrape and blackbox target, and the `authentik-blueprints` alert group
(`AuthentikBlueprintError` recency-based and keyed on path,
`AuthentikBlueprintCollectorDown`, `AuthentikBlueprintInstanceCountLow`) plus
the runbook. Part of eblume/blumeops#1444.
