`TextfileStale` no longer goes pending every hour. Its threshold was 3600s
while `borgmatic.prom` is written by an hourly LaunchAgent — the alert's
threshold and the file's refresh period were the same number, so ordinary
scheduling jitter made it "stale" once per hour, every hour. Raised to 2h; the
other five textfiles refresh every 20-50s and lose nothing. Shortening the
exporter's interval was the other option and was rejected: it calls `borg info`
over SSH to BorgBase, and doubling that collides with the separate
connection-count concern.
