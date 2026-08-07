Every `op read` in `mise-tasks/` now runs with `stdin=subprocess.DEVNULL` and a
30s timeout, and every caller handles `TimeoutExpired`. `subprocess.run(...,
capture_output=True)` redirects stdout and stderr but leaves stdin inherited, so
`op` — which misparses a non-TTY stdin — could block forever on a parent whose
stdin was a pipe, with no timeout to break it. Four tasks (`branch-cleanup`,
`dns-acme-cleanup`, `spork-create`, `container-build-and-release`) were missing
the stdin redirect outright, and `spork-create` and `container-build-and-release`
turned a nonzero exit into an uncaught `CalledProcessError` traceback rather than
a message saying which secret could not be read.

The hang is reproducible without touching a real vault: give a parent process a
stdin pipe nobody writes to, put a shell `op` that does `read x` on PATH, and the
call never returns; `stdin=DEVNULL` makes it return immediately.
