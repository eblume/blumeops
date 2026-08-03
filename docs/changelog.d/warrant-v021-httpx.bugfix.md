warrant v0.2.1: `/auth/callback` 500'd — `httpx` was lazily imported and
missing from the image (smoke tests masked it). Now a top-level import
(missing deps fail at boot, not first login) and in the nix package set.
