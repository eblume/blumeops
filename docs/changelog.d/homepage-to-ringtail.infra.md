Migrated homepage dashboard from minikube (indri/arm64) to k3s (ringtail/amd64).
The container is now built via nix (`containers/homepage/default.nix`), adapted
from nixpkgs `homepage-dashboard` with the upstream Next.js cache patches and
wrapped with `dockerTools.buildLayeredImage`. Autodiscovery shifts: services on
minikube (ArgoCD, Immich, Kiwix, Mealie, Miniflux, Grafana, Prometheus,
Navidrome, Paperless, TeslaMate, Transmission) become explicit static entries
in `services.yaml`; ringtail services (Authentik, Frigate/NVR, Ntfy, Ollama)
auto-populate via Ingress annotations.
