The post-upgrade `doctor check` in [[upgrade-forgejo]] now runs. It was written
as `cd ~/forgejo && forgejo doctor …`, but Forgejo derives its work path from the
binary's own directory rather than the shell's, so it looked for `app.ini` under
`~/code/3rd/forgejo` and exited with "Unable to load config file for a installed
Forgejo instance". It needs `-w` and `-c` before the subcommand, the same two
flags the LaunchAgent passes. Found while verifying the v16.0.2 upgrade.
