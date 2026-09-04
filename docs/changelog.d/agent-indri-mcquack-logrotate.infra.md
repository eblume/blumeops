Add an hourly mcquack.eblume.logrotate LaunchAgent to indri that copy+truncates every ~/Library/Logs/mcquack.*.log over 256 MiB (3 generations kept).
The in-place truncate is because launchd holds O_APPEND fds, so mv-based rotation would leave services writing into the renamed file. Bounds the unbounded launchd log growth (forgejo logs hit 5.2 GB).
Part of eblume/blumeops#798.
