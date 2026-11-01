# Red fixture: ringtail-flake-check.fod-eval

A case this gate must reject: a fixed-output derivation in ringtail's closure
that is not on the allowlist, for example one whose post-fetch step runs a
downloaded artifact (`decode = "xz -d"`). The `fod-eval` job runs
`fod-eval-check --ringtail` on `indri-build`, and `check` (the builder build)
does not start unless that verdict is green.

This file is a pointer, not an overlay: the `fod-only-downloads` aspect scans
every `*.nix` in the repo, so the case is not copied here. The tool-level
rejection is `fod-eval-check/test_check.py::test_red_fixture_rejected`.
