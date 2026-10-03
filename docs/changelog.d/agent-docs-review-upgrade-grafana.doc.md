Docs review: fixed `how-to/grafana/upgrade-grafana.md` — the migration
bullet named a single ArgoCD app at `argocd/manifests/grafana/`, which no
longer exists after the `-ringtail` rename. It now lists both apps:
`grafana-ringtail` and `grafana-config-ringtail`.
