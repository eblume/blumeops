The Fly proxy auth-key rotation runbook now replaces the key with `tailnet-up -- --replace <flyio-proxy-key URN>`; a plain `tailnet-up` or `--refresh` was a no-op before expiry.
