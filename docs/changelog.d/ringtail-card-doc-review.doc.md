Fix drift in the [[ringtail]] card from doc review: ArgoCD now runs in-cluster
(the indri cluster-registration era is gone, including the manual `argocd
cluster add` section), secrets sync is 3 apps (the `ClusterSecretStore` moved
into `external-secrets-ringtail` with the ESO kustomize migration), snowflake
metrics bind `0.0.0.0:9999`, factorio uses an exact CNAME (not an A record),
the workloads table is a labeled subset of the 36 ArgoCD apps, and the
`ringtail-priv-runner` warrant sandbox is documented.
