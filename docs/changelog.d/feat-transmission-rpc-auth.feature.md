Transmission RPC now requires authentication (credentials in 1Password via
external-secrets), closing the open-RPC finding from the 2026-07 DMCA
investigation. The kiwix torrent-sync sidecar and Prometheus exporter
authenticate with the same secret, and the homepage Transmission widget is
enabled now that credentials exist.
