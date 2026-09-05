Bump the Nix-built Grafana Alloy image (containers/alloy) from v1.16.3 to
v1.19.2, the latest upstream release (2026-08-26): v1.17.1, v1.18.1 (Go CVE
backports GO-2026-6061/GO-2026-5970), and v1.19.2. None of the breaking
changes in that range (v1.18.0's otelcol kafka/splunkhec removals, v1.19.0's
prometheus.write.queue) touch any of our configs. The v1.19 Makefile embeds
Beyla v3.28.0 eBPF binaries into the alloy binary; the recipe now pre-fetches
those tarballs (pinned by the in-tree beyla_version.yaml sha256s) and builds
with SKIP_CODE_GENERATION, so the build stays offline. The goModules and
npmDepsHash fixed-output hashes are TOFU (fakeHash), pinned from the
build-container run(s) that report them, per the #790 precedent. The alloy-ringtail
DaemonSet newTag pin lands in a follow-up PR once the build is green;
alloy-tracing-ringtail stays on v1.16.3 until its own review.
