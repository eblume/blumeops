talos pod: fix nix builds colliding with the image's own store paths. The
image's root-owned store paths were unknown to the pod's fresh store DB, so
any substitution whose closure overlapped them failed (nix tried to
delete-and-replace the incumbent; root ownership refused). The image now
bakes closureInfo's registration dump of the image closure, which the
entrypoint loads, gcrooting the toolchain; registered
paths are reused instead of re-downloaded. Also create `/nix/var/nix` in the
image — its absence made nix fall back to a chroot store that cannot build.
Verified in-pod on v0.2.9: registration + `hello` build end-to-end.
