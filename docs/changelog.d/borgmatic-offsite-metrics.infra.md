Closed a [[borgmatic]] monitoring blind spot: the metrics collector never
scraped the main BorgBase offsite repo (only `sifaka-local` and the immich
photos repo were configured), so a failed offsite run produced no metric and no
alert — BorgBase's own email was the only signal. Added the offsite repo to the
collector and a `BorgmaticStale` Grafana alert (fires when any repo's newest
archive is older than 30h, ~7h after a missed nightly run). The hourly per-repo
poll stays metadata-only (`borg info`/`list`); the heavy per-source manifest
listing is now skipped for remote repos to avoid pulling a 100k-entry file
manifest over the internet every hour. Also corrected the metrics script's
stale `/opt/homebrew/var/forgejo` source-path mapping to `~/forgejo`.
