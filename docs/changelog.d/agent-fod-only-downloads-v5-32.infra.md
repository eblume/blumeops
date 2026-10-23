aspect fod-only-downloads: invariant over every *.nix that nothing downloaded executes
inside a FOD — a FOD (including ones nixpkgs builders create: buildGoModule vendor in
plain and finalAttrs-lambda form, npm/pnpm deps fetches, fetcher postFetch; fetchMixDeps
is red) runs only fetcher primitives, the allowlisted no-execute fetch modes (go mod
download with GOTOOLCHAIN=local, npm ci --ignore-scripts) and inert plumbing; non-literal
phase values and setup hooks unguarded by ${outputHash-} are red; no exception list
(eblume/blumeops#1809).
