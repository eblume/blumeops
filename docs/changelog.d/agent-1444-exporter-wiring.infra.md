authentik blueprint-state exporter wired into the `authentik` app: standalone
Deployment + Service (image pinned by digest), an alloy-ringtail scrape, and
the `authentik-blueprints` alert group (`AuthentikBlueprintError`
recency-based over 75m and keyed on path,
`AuthentikBlueprintCollectorDown`, `AuthentikBlueprintInstanceCountLow`) plus
the runbook. Part of eblume/blumeops#1444.
