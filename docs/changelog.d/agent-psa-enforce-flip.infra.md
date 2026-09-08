Switch on `pod-security.kubernetes.io/enforce: restricted` for the
authentik, immich, mealie, paperless, and teslamate namespaces — step 3 of
the PSA rollout (heph `01KVQX81703HDE77ED88XDPSR2`), the first `enforce`
labels in the fleet. Warnings were verified quiet after the non-root rollout
(#872, #885, #890). The grafana, birdnet-go, and frigate exceptions stand;
`apps` is manual-sync, so the labels apply on the next `argocd app sync apps`.
