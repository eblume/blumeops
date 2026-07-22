Service review: upgraded navidrome v0.61.1 → v0.63.2 by self-pinning the
container's nixpkgs to nixos-unstable (mealie precedent — ringtail's stable
25.11 nixpkgs lags at 0.61.1). Picks up the v0.62.0 security fixes
(cross-account share disclosure, authorization checks, transcode-DoS cap)
and the v0.63.x scanner/search overhaul. Sharing stays off
(`ND_ENABLE_SHARING=false` pinned — v0.63.0 flips the default to enabled).
The Build Container workflow now fails fast with a clear error when
dispatched with a short commit SHA (actions/checkout treats those as
branch names; see run #665).
