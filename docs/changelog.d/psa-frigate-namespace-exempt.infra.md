The frigate namespace drops its PSA warn/audit labels: frigate is a documented
exception (root s6-overlay entrypoint, no upstream non-root path), so the
`restricted` warnings on every sync were noise with no action behind them.
