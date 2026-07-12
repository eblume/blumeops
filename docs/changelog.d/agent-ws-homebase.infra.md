Agent workspaces collapsed from per-repo Remote Control servers
(`ringtail-{hephaestus,research,playground,parsimony}`) to a single home-base
session, `ringtail-agent`, rooted in the new [`agents`
repo](https://forge.eblu.me/eblume/agents) whose `AGENTS.md` carries the base
instructions (repo map, toolbox, execution environments). All other repos are
sibling checkouts the session `cd`s into; the `playground` workspace is dropped
(a home-base worktree is already a scratch space).

Also: `heph` for Erich on ringtail — a second hephd spoke (`eblume-heph-spoke`,
token-file store, logging in as Erich himself) alongside the agent's, with the
shared version pin and install machinery extracted to
`nixos/ringtail/heph-common.nix`.
