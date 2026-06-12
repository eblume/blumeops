[[retire-minikube]] phase 6: the indri forgejo-runner flips to
host-mode jobs (no more `runner-job-image`; jobs run as `erichblume`
with the mise toolchain, which gains pinned `dagger` and `prek`).
Scope revision: Docker Desktop stays as the dagger engine host
(hephaestus/cv CI also use dagger), right-sized from 6cpu/8GiB to
2cpu/4GiB. All stale arm64 build files deleted and
`build-container.yaml` is nix-only.
