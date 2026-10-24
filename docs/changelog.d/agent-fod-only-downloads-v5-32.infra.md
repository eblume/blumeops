aspect fod-only-downloads: fast per-PR structural pre-check over every *.nix for the
invariant that nothing downloaded executes inside a FOD (the invariant itself is the
evaluation-based check in eblume/blumeops#1860) — a FOD (including ones nixpkgs builders
create: buildGoModule vendor in plain and finalAttrs-lambda form, npm/pnpm deps fetches,
fetcher postFetch; fetchMixDeps is red) runs only fetcher primitives, the allowlisted
no-execute fetch modes (go mod download with GOTOOLCHAIN=local, npm ci --ignore-scripts)
and inert plumbing; non-literal phase values, setup hooks unguarded by ${outputHash-},
and non-allowlisted environment variables however they are set (export, bare
assignment, env prefix, env attrset key) are red; no exception list
(eblume/blumeops#1809).
