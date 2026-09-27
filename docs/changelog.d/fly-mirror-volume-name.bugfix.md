Rename the static forge mirror's Fly volume to `git_mirror` (Fly rejects hyphens in volume names), and make `fly-setup` create it non-interactively and stop leaking a dedicated IPv6 on every run.
