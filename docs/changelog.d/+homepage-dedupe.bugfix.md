Fixed duplicate homepage entries (DJ/Navidrome, Kiwix, Miniflux, ArgoCD,
Grafana, Prometheus, Transmission) after [[retire-minikube]] — the static
`services.yaml` entries that covered the formerly-invisible minikube services
now collided with k8s Ingress annotation auto-discovery on ringtail. The
annotations are the source of truth; the static duplicates are removed.
