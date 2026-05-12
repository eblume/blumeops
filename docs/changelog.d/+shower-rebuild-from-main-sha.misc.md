Rebuild shower v1.1.0 container from main HEAD (`3c7967e`) and bump the
kustomization tag to `v1.1.0-3c7967e-nix`. The PR was squash-merged, so
the branch commit `444ff91` baked into the prior tag isn't reachable
from main's history. The new tag points at a commit that exists on
main; image content is byte-identical because the FOD output is content
addressed and the inputs didn't change.
