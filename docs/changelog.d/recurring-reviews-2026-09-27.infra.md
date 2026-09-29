Daily service review: loki (argocd, last reviewed 2026-06-12). Bumped the
Nix-built Loki image (containers/loki) from v3.7.2 to v3.7.8, the latest
release on the 3.7 train. The v3.7.3-v3.7.8 span is patch releases:
dependency/security bumps (notably grpc HIGH advisories in v3.7.8) plus a
v3.7.5 ingester flush-race fix and v3.7.6 queryrange sketch fix; the only
marked breaking change is v3.7.3's OpenShift stream-labels default, which
does not apply to this deployment. The v3.7.8 fetchgit hash was verified
in-pod against the forge mirror; the kustomization newTag lands in a
follow-up PR opened by horkos once the merge-triggered build is green.
