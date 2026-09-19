borgmatic: all three k8s dump hooks (file, tar, sqlite) now select only Running pods, so a lingering Evicted pod (talos, 2026-09-18) can no longer abort the nightly backup.
