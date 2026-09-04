Set `User 1000` on the five local nix container images whose root defaults
wedged the PSA step 2 restricted fields (authentik-redis, valkey, mealie,
paperless, teslamate), per the signed-off decision table in
docs/reference/operations/security.md. Teslamate additionally gets a
writable uid-owned /opt/app (HOME, SRTM_CACHE). No manifest or
kustomization change yet: the securityContext flip and the newTag pins
land together in a follow-up PR after the build-container rebuilds, so
each workload gets image and fields atomically.
