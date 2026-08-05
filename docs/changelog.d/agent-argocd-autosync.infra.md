ArgoCD workload applications now sync automatically on merge to `main`
(`prune` and `selfHeal` both off). A merge reaches the cluster without a
separate sync step; `git revert` becomes a real rollback. The `apps`
app-of-apps, ArgoCD's self-management app, and the two apps tracking mutable
mirror tags stay manual.
