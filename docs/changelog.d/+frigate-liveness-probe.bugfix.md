Relaxed the `frigate` liveness probe (`timeoutSeconds: 10`, `failureThreshold: 5`;
readiness `timeoutSeconds: 5`). The default 1s timeout / 3 failures was killing the
pod with SIGTERM on transient API stalls — 206 graceful-shutdown restarts over 36d,
never an OOM — whenever frigate's API thread blocked under detector/GPU load or NFS
recording I/O. The pod now tolerates ~2.5min of unresponsiveness before a restart.
