Tailscale operator stack: upgraded v1.94.2 → v1.98.5 (operator, proxy, and the
new local k8s-nameserver), rebuilt from the forge mirror with the `go_1_26`
buildGoModule override (v1.98.5 go.mod floor is >= 1.26.3). The in-cluster
MagicDNS nameserver is now a local nix-built image
(`containers/tailscale-k8s-nameserver/`), replacing the floating
`docker.io/tailscale/k8s-nameserver:stable` tag — that mutable tag was the
vector behind the v1.96.5 MagicDNS-in-containers regression.
