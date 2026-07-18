Fixed the Ringtail Flake Update workflow hanging in its summary step (`git
log` spawned a pager on the runner; now `--no-pager`), and two latent bugs in
the dagger `flake-update` pipeline: `skip_inputs` was never applied
(single-quoted `$SKIP_INPUTS` never expanded, so a real update would have
bumped the pinned `nixpkgs-services` input), and an empty discovered-input
list now fails loudly instead of falling back to a bare `nix flake update`
of everything.
