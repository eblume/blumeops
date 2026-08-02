Dedicated privileged runner ([[warrant-approval-gated-runs]] Phase 2):
`ringtail-priv-runner`, a sandboxed NixOS DynamicUser instance carrying the
`priv` label — privileged dispatch-only jobs move off host-mode
`erichblume@indri`. The indri runner drops `priv`; argocd-deploy prefers the
runner's nixpkgs `argocd` with a mise-x fallback.
