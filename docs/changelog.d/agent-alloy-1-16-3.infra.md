Bump the Nix-built Grafana Alloy image (containers/alloy) from v1.16.0 to
v1.16.3, the latest patch on the 1.16 train. Pulls in v1.16.2's security
fixes (pgx v5.9.2, x/crypto + x/net CVE updates) and the v1.16.3
cluster-TLS join fix. The alloy-tracing-ringtail manifest newTag lands in
a follow-up commit once the build-container warrant build is green; the
full v1.19.2 upgrade is deferred to heph task 01M1GJW5H9T8EXNPH94QW4PNK9
(v1.18/v1.19 carry breaking changes the other alloy configs are not
reviewed against yet).
