aspect fod-only-downloads: invariant over every *.nix that nothing downloaded executes
inside a FOD — a FOD runs only fetcher primitives, the allowlisted no-execute fetch modes
(go mod download, npm ci --ignore-scripts) and inert plumbing; no exception list
(eblume/blumeops#1809).
