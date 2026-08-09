`prek run --all-files` is clean again. Five Python files had drifted out of
`ruff-format` shape — `containers/warrant/app/main.py`, two warrant tests and two
`tests/` modules — so the hook rewrote them on every invocation and any run that
touched them reported a failure. Formatting only, no behaviour change. Nothing
caught it because blumeops CI runs Docs Checks rather than prek, so the hooks are
enforced only by whoever happens to run them locally.
