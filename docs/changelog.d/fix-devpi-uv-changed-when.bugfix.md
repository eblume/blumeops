Fix devpi role change detection: `uv pip install` reports to stderr, so version
bumps installed silently without triggering the restart handler — the 6.20.3
upgrade sat installed-but-not-running until a manual restart.
