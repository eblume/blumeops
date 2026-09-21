argocd-deploy `revision=declared` resolves the live targetRevision with `jq` instead of `python3`, which the priv runner does not carry (warrant #103 failed with `python3: command not found`).
