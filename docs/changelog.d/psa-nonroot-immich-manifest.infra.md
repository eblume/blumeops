immich-server and immich-machine-learning now run as uid/gid 1000 with the
PSA restricted fields (runAsNonRoot, allowPrivilegeEscalation:false,
capabilities drop ALL) — upstream's rootless `user: 1000:1000` pattern via the
manifest, since both are upstream images. ML gets fsGroup 1000 on its cache PVC
plus emptyDirs at `/.config` and `/.cache`; the server's NFS library gets no
fsGroup and, on inspection, needs no pre-chown either (the sifaka share is
0777 throughout). Increment of the #797 decision table.
