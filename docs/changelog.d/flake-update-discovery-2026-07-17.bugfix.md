Fixed flake input discovery in the dagger `flake-update` pipeline: nix cannot
`readFile /dev/stdin` (it canonicalizes to a `/proc/.../pipe:[...]` path), so
discovery had been silently empty since the pipeline was written, degenerating
every run into a bare `nix flake update` of all inputs — the `nixpkgs-services`
pin survived only because its URL is rev-pinned. Metadata now lands in a real
file, stderr is no longer suppressed, and run 658's "refusing bare flake
update" guard failure becomes a green no-op again.
