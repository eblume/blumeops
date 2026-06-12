[[retire-minikube]] phase 5: minikube fully decommissioned. The 12
remaining minikube manifest dirs deleted, ansible `minikube`/
`minikube_metrics` roles removed, the Caddy L4 `:5432` route and its
`.pgpass` line retired, `services-check` rewritten for the
single-cluster world (ArgoCD app table now reads ringtail),
`ensure-minikube-indri-kubectl-config` deleted, the compliance report
tooling's minikube node-verification removed (k3s equivalent tracked in
heph), tailnet tags `tag:k8s-api`/`tag:loki`/`tag:pg` swept from
pulumi, and the docs sweep (AGENTS.md rule 2 inverted to k3s-ringtail,
restart-indri/architecture/cluster/tailscale-operator/indri/
disaster-recovery cards revised, rebuild-minikube-cluster deleted).
