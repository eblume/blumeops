Move paperless, teslamate, and mealie off `minikube-indri` onto
`k3s-ringtail`, shedding ~1.1 GiB of resident load from the
OOM-thrashing 8 GiB minikube node (the kernel OOM killer had been
killing `kube-apiserver`/`dockerd`/argocd, flapping every
minikube-hosted service at once). paperless + teslamate databases
move into a fresh CNPG `blumeops-pg` cluster on ringtail via a cold
`pg_dump`/`pg_restore` from the quiesced source — row counts verified
equal before any routing flip; source DBs dropped only after the
ringtail side serves traffic. mealie's SQLite PVC is copied as-is.
paperless media stays on sifaka NFS. Downtime-tolerant cold cutover
(no streaming replication); rollback is repoint-and-scale-up with the
source untouched. Second chain in the indri-k8s decommission after
[[migrate-immich-to-ringtail]].
