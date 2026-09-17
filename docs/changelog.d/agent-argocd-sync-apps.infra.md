Add the `argocd-sync-apps` warrant action: sync the app-of-apps root (`apps`)
from a bound SHA — pin the root to the SHA, sync, wait healthy, then reset it
to tracking `main`. `argocd-deploy.yaml` with `app=apps` cannot do this
without leaving the root pinned, which reads `Synced` against the pin and
silently ignores later `argocd/apps/` merges; `argocd-deploy` (its allowlist
and the `argocd-app` validator) now refuses `app=apps` outright, so
`argocd-sync-apps` is the only route to the root.

The root sync turns each `argocd/apps/*.yaml` into a live ArgoCD Application
(a pointer tracked forever with automated sync), so `argocd-sync-apps` and a
new Lint PR check both run `mise-tasks/validate-argocd-apps` to refuse any
Application whose source the agents bot can move (its fork, on a branch) —
only the canonical `eblume/blumeops.git @ main` and read-only mirrors are
allowed. AGENTS.md, [[argocd]], [[horkos]], [[request-a-privileged-run]],
[[agent-change-process]] and the deploy-k8s-service how-to updated.
