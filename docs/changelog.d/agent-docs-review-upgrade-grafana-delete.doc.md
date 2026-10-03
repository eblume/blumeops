Docs: delete `how-to/grafana/upgrade-grafana.md` per review — it is a one-off
migration record (Helm → Kustomize, 11.4.0 → 12.3.3). The one general bit, the
version-bump → build → pin-PR upgrade flow, moved into the [[grafana]] service
reference card as an "Upgrading" section; dead [[upgrade-grafana]] links in
[[build-grafana-images]] and [[kustomize-grafana-deployment]] removed.
