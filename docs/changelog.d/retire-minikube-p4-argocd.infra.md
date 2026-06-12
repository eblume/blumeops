[[retire-minikube]] phase 4: ArgoCD self-migrated to ringtail k3s — the
last workload off minikube. All 32 ringtail app destinations rewritten
to in-cluster, the 13 minikube-only Application definitions deleted
(their live workloads run unmanaged until phase 5), the argocd metrics
job back in-cluster, and the admin password rotated on the fresh
install. Minikube's ArgoCD is scaled to 0 as rollback.
