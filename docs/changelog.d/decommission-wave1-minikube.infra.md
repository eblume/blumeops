Decommission the wave-1 services on minikube-indri now that paperless,
teslamate, and mealie run on ringtail with their data backed up. Removes the
minikube `paperless`/`teslamate`/`mealie` manifest dirs + ArgoCD app
definitions (pruning the parked Deployments, Services, and the redundant
minikube mealie/paperless PVCs), and drops the `paperless`/`teslamate` roles
from the minikube `blumeops-pg` cluster. The `paperless` and `teslamate`
databases are dropped from indri's blumeops-pg as the finalization step.
miniflux + authentik remain on the minikube cluster (later waves).
