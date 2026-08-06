`role:workflow-bot` can read ArgoCD projects. Without it `argocd app get` was
denied, so the argocd-deploy workflow's closing "Report application state"
step — the run's audit record — has been empty on every warrant-gated deploy
(runs 713, 721, 732), hidden by the step's `|| true`.
