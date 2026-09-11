Alloy image: bump the embedded Beyla eBPF binary from v3.28.0 to v3.33.0.
v3.28.0's vendored OBI predates the uprobe-preemption guard (OBI #3059,
fixed in OBI v0.12.1) that stopped the 2026-09-10 ringtail kernel panic —
a NULL deref in obi_protocol_tcp while uprobing a freshly rolled
tailscaled sidecar. v3.33.0's OBI pin carries the fix (verified 10 commits
ahead of the fix merge). Alloy itself stays v1.19.2; the build now
re-pins the alloy source's in-tree beyla_version.yaml to the shipped
binaries so the Makefile download step stays a no-op. Beyla stays
disabled in alloy-tracing-ringtail (see the beyla-disable fragment) until
the re-enable PR; the image pin PR follows the build-container run.
