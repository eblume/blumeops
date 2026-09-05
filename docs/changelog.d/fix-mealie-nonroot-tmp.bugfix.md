mealie (non-root) also needed a writable `/tmp` — the nix image ships none and
gunicorn's worker heartbeat file requires one. emptyDir added at `/tmp`.
