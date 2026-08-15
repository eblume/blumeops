Add `talos` to the agents repo pool (`access: write`, `pool: canonical`),
granting the `agents` bot collaborator write on `eblume/talos` and checking
the repo out in agent workspaces. Talos is entering active agent-driven
development (web-UI features land as branch + PR like the other canonical
repos); without a pool entry the reconciler denies the bot access, so pushes
from the talos pod are rejected.
