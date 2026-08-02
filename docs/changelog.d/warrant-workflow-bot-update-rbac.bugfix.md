ArgoCD `workflow-bot` RBAC gains `applications update` so the argocd-deploy
workflow can `app set --revision`. Pairs with re-minting its stale token —
the provisioned `ARGOCD_AUTH_TOKEN` was signed by the retired minikube-era
ArgoCD and fails on the ringtail instance (`token signature is invalid`).
