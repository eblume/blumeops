Bumped the Grafana dashboard ConfigMap watcher (kiwigrid k8s-sidecar) from
2.6.0 to 2.10.1 in the Nix-built `blumeops/grafana-sidecar` container:
health server now falls back to IPv4 when IPv6 is unavailable (plus a
`HEALTH_HOST` override), LIST-mode cache cleanup is scoped per namespace,
and `REQ_USERNAME_FILE`/`REQ_PASSWORD_FILE` env vars were added. No changes
to the WATCH/LIST ConfigMap behaviour the deployment uses. The 2.10.1 fetch
hash was computed and the full image built and import-smoke-tested inside
the talos pod; the Build Container CI dispatch and the ArgoCD deploy are
human-side.
