Executor gets `TALOS_EPHEMERAL_LIMIT_BYTES` from the downward API, so the aggregate nix-store guard sizes against its real 160Gi limit instead of the 40 GiB fallback.
