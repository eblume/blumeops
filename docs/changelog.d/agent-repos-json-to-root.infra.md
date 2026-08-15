Move `repos.json` from `containers/agent-ws/` to the repo root. The file
has outgrown agent-ws: it defines both the `agents` bot's forge access
policy and the workspace checkout pool, and the pool is now consumed by two
images (agent-ws *and* talos — the latter already read it cross-directory,
`../agent-ws/repos.json`). Root placement reflects that it is org-level
agent policy, not container config, and survives agent-ws' eventual
retirement. Pure source-tree refactor: both container `default.nix` files
bake it at build time (`readFile`), the reconciler mise task, the workflow
path filters, and doc references are updated to match. Nothing reads it at
runtime.
