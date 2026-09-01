Add the four PSA restricted-required fields (`runAsNonRoot`, `seccompProfile`
at pod level; `allowPrivilegeEscalation: false`, `capabilities: drop ALL` at
container level) to the near-miss workloads in restricted-labeled app
namespaces — step 2 of the PSA rollout in heph
`01KVQX81703HDE77ED88XDPSR2`. The pinned upstream ArgoCD chart gets its five
pod-level gaps via a kustomize strategic-merge patch
(`argocd-security-patch.yaml`). Excludes grafana's root `init-chown-data`
container (needs a non-root chown pattern, follow-up), birdnet-go (added in
#765 after the label pass; its upstream image runs as root, so a field
addition would not start), and the baseline/exempt namespaces. Part of
eblume/blumeops#753.
