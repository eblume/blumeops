The talos pod's nix can now **build**, not just evaluate: the image's top
layer chowns the canonical `/nix/store` to the container user, so store-path
hashes stay canonical and `cache.nixos.org` substitutes. Builds run
unsandboxed (seccomp forbids user namespaces) inside the already-fenced pod,
capped by `max-jobs = 2` and a new `ephemeral-storage` limit on the
Deployment. `docs/explanation/agent-containerization.md` §"Nix in the pod"
records the eval-only phase this supersedes.
