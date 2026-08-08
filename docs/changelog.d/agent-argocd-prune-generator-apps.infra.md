The thirteen ArgoCD apps that render config through a kustomize
`configMapGenerator` now sync with `prune: true`. Each content edit produces a
new hash-suffixed ConfigMap; with prune off the superseded one was never
deleted, so the app read `OutOfSync` indefinitely and `ArgoCDAppOutOfSync` fired
on a deploy that had worked exactly as intended. `selfHeal` stays off, and the
remaining apps keep `prune: false`.
