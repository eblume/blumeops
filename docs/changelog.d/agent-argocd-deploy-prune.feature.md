`ArgoCD Deploy` takes a `prune` input, so clearing orphaned resources is
reachable through the approval-gated route instead of only from gilbert. Apps
sync with `prune: false`, so the thirteen whose manifests use a kustomize
`configMapGenerator` strand their previous hash-suffixed ConfigMap on every
content edit; ArgoCD counts the orphan as pending-prune and the app reads
`OutOfSync` forever, tripping `ArgoCDAppOutOfSync` on a merge that deployed
exactly as intended. `argocd app sync --prune` is the documented fix and neither
automated sync nor the gated workflow could run it.

`prune` defaults to false, is refused without `sync=true` rather than silently
no-op'ing, and logs an `--dry-run` preview of what it is about to delete before
deleting it — this run log is the audit record. The `warrant-policy.yaml` entry
lands in the same change, per the rule that a capability and its boundary get
reviewed together.

Also adds `indri` and `priv` to `.github/actionlint.yaml`. actionlint errors on
an unrecognised `runs-on` label and that error is per-file, so their absence made
10 of the repo's 12 workflows unlintable; all 12 now pass.
