Pin the talos image to v0.2.10-b9c2cb3-nix (build run 1075). The v0.2.10
image registers the image's own store paths into the pod's nix DB at
startup and creates /nix/var/nix — the two fixes from PR #581. Merge
auto-syncs the talos app and restarts the pod. Post-deploy smoke test:
nix-build hello must succeed in a fresh pod with no manual setup.
