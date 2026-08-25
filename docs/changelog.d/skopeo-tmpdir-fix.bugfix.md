Fixed `build-container.yaml` pushes of large images: the nix-container-builder
runner's sandbox (`DynamicUser` → `PrivateTmp`) mounts /var/tmp as a ~3.2G
tmpfs, and skopeo staged the whole docker-archive there — big images failed
with `short write` (runs 1659/1662, prowler 5.39.1). skopeo now uses
`--tmpdir` pointed at the disk-backed job workspace.
