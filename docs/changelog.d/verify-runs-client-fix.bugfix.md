Fixed `mise run verify-runs` crashing with "Cannot open a client instance
more than once" when run from gilbert — same probe-opens-the-returned-client
bug fixed in `request-run` (b92042d3); `_ops_client()` now probes with a
throwaway client.
