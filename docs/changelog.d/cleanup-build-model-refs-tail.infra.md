Pruned the remaining dead `container.py`/`Dockerfile` build-model references
left after [[retire-minikube]]. `container-list` and `service-review` mise tasks
dropped their `has_container_py`/`has_dockerfile` classification branches (every
container is now `containers/<name>/default.nix`), and the `upgrade-grafana` and
`deploy-prowler` how-tos now point at the nix builds instead of the retired
Dockerfiles.

Also reconciled the CI runner/dagger docs with the phase-6 host-mode reality
(jobs run directly on [[indri]] with the mise toolchain — no job container, no
`runner-job-image`): rewrote [[upgrade-dagger]] around the mise-pinned host CLI,
fixed the runner-environment section of the update-documentation how-to and the
job model in [[configure-launchd-runner]], and deleted the obsolete
configure-k8s-runner how-to (superseded by [[configure-launchd-runner]]),
repointing its inbound links.
