Rolled back the PSA step 2 restricted fields on the eight workloads whose
images run as root (authentik-redis, frigate, immich server/ml/valkey, mealie,
paperless, teslamate). `runAsNonRoot: true` wedged their pods in
`CreateContainerConfigError` ("image will run as root"), taking mealie,
frigate, paperless and immich-valkey fully offline. The remaining #772
hardening stays in place; a follow-up decides non-root images vs documented
exceptions for these eight.
