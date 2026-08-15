Bake an eval-only nix into the talos image (agent-ws precedent):
`$HOME`-relocated store on the PVC (`NIX_{STORE,STATE,LOG,CONF}_DIR` in the
image config), `max-jobs = 0` nix.conf, size-swept by the entrypoint. Lets
the talos pod compute `srcHash` values for its own image bumps via
`nix-prefetch-git` instead of guessing and burning warrant-approved Build
Container rounds on hash-mismatch errors — the pod that needed this was
caught computing a wrong hash by hand during the v0.2.4 release. Version
bump 0.2.3 → 0.2.4 for the toolchain change.
