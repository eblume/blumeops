Add `sn2-prelaunch` Steam launch wrapper on ringtail that removes
Subnautica 2's stale `Saved/running.dat` and `Saved/beforelobby.dat`
lockfiles before each launch. SN2 pops up an invisible (0×0-sized)
Error dialog when it detects an unclean exit, blocking GameThread
forever; this is observable only as a black screen with a spinning
loader. Use via Steam launch option: `sn2-prelaunch %command%`.
