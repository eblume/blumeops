aspect fod-only-downloads: invariant over every *.nix that nothing downloaded executes
inside a FOD — a FOD (including ones nixpkgs builders create: buildGoModule vendor,
npm/pnpm deps fetches, fetcher postFetch; fetchMixDeps is red) runs only fetcher
primitives, the allowlisted no-execute fetch modes (go mod download with
GOTOOLCHAIN=local, npm ci --ignore-scripts) and inert plumbing; no exception list
(eblume/blumeops#1809).
