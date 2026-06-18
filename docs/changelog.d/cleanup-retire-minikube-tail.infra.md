[[retire-minikube]] tail cleanup: pruned the dead container-build framework.
Removed the `build`, `publish`, and `container_version` Dagger functions (and
the now-orphaned `containers.py` `container.py`-discovery module) — the
Dockerfile/`docker_build()` and native-`container.py` build paths were retired
when the minikube/arm64 runner went away, leaving nix as the only container
build path. Updated [[dagger]] and [[build-container-image]] to document the
nix-only reality.
