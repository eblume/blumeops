`mise run request-run` crashed on gilbert ("Cannot open a client instance
more than once"): `_ops_client()`'s healthz probe implicitly opened the
client it returned, so the caller's `with` failed on `__enter__`. Only the
direct route hit it — in the pod the probe fails and the SOCKS fallback
client is returned unopened, which is why agent sessions never saw it. The
probe now uses a throwaway client.
