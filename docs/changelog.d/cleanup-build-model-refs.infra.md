[[retire-minikube]] tail cleanup (follow-up): simplified the container build
tooling to nix-only. `container-version-check` now validates each container's
`default.nix` against `service-versions.yaml` (dropped the dead container.py
`VERSION` / Dockerfile `ARG` rules), and `container-build-and-release` no longer
carries dead container.py/Dockerfile classification. Stale build-model
references purged from docs (forgejo, forgejo-runner, dagger tooling,
grafana-image how-to, review-services, zot CI-auth) and the
`build-container.yaml` workflow comment.
