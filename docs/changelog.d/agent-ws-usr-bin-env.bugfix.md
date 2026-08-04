The agent-ws image gains `/usr/bin/env`, so `mise run <task>` works in the
pod — the kernel resolves shebang interpreters literally, and every
mise-task script uses `#!/usr/bin/env`. Tasks needing the blumeops vault are
now tagged `[human]` in their descriptions, and AGENTS.md points agents at
`agent-health` rather than the kubectl/ssh-bound `services-check`.
