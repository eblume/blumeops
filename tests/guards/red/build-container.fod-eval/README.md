# Red fixture: build-container.fod-eval

A case this gate must reject: a fixed-output derivation whose post-fetch step
runs a downloaded artifact (`decode = "xz -d"`, not on the allowlist). The
rejection is proven at the tool level by
`fod-eval-check/test_check.py::test_red_fixture_rejected` over
`fod-eval-check/fixtures/red/fetchpatch-unlisted-postfetch.nix`; the `fod-eval`
job runs that same `fod-eval-check` over the changed containers.

This file is a pointer, not an overlay: the `fod-only-downloads` aspect scans
every `*.nix` in the repo, so the case is not copied here.
