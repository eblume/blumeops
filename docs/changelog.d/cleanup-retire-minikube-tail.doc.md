Doc review: purged retired-minikube references from the four alerting runbooks
(service-probe-failure, postgres-unhealthy, pod-not-ready, textfile-stale) —
`--context=minikube-indri` → `--context=k3s-ringtail`, "indri's minikube
cluster" → "ringtail's k3s cluster", and minikube health checks → k3s-on-ringtail
equivalents. Also corrected the textfile-stale collector table (dropped the dead
`minikube.prom`, added the live `forgejo.prom` and `macos_power.prom`).
