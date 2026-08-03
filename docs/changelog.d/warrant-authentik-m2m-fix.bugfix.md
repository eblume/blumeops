Fix the silently-skipped `agents-m2m` blueprint entry: the OAuth2 provider
needs `redirect_uris` even for a pure client_credentials flow (discovery
404'd; every working provider in the file has one). Placeholder points at
Warrant's future callback. Also aligns the service account with the zot-ci
shape (`is_active` instead of `path`).
