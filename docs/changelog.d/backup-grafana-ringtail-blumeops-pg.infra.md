Wire the ringtail `blumeops-pg` cluster (which holds the wave-1-migrated
paperless + teslamate databases) into backups and Grafana. Adds a Tailscale
LoadBalancer Service (`blumeops-pg-ringtail.tail8d86e.ts.net`) and a Caddy L4
route (`pg.ops.eblu.me:5434`), then repoints borgmatic's `teslamate` +
`paperless` postgres dumps and the `mealie` SQLite dump at ringtail, and the
Grafana TeslaMate datasource at the ringtail DB. Closes the backup gap that
opened at cutover (the migrated live data was still being backed up from the
now-frozen minikube copies) and unblocks the wave-1 decommission.
