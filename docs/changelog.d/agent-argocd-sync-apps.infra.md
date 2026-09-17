Add the `argocd-sync-apps` warrant action: sync the app-of-apps root (`apps`)
from a bound SHA — pin the root to the SHA, sync, wait healthy, then reset it
to tracking `main`. `argocd-deploy.yaml` with `app=apps` cannot do this
without leaving the root pinned, which reads `Synced` against the pin and
silently ignores later `argocd/apps/` merges. AGENTS.md, [[argocd]],
[[horkos]], [[request-a-privileged-run]] and the deploy-k8s-service how-to
updated.
