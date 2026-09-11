Pin the alloy image to v1.19.2-45387b3-nix in both alloy-ringtail and
alloy-tracing-ringtail: the first build of the image carrying the embedded
Beyla v3.33.0 eBPF binary (beyla v3.33.0's vendored OBI carries the
uprobe-preemption guard that fixed the 2026-09-10 ringtail kernel panic).
Beyla stays disabled in alloy-tracing-ringtail until the allowlist
re-enable PR lands.
