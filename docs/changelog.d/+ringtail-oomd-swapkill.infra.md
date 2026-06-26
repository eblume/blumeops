Enabled `systemd-oomd` swap-kill on ringtail (`systemd.oomd.enableRootSlice`,
`SwapUsedLimit=80%`). A Crusader Kings 3 spike filled zram swap to ~95% and froze
the whole host in a multi-minute memory-pressure stall (PSI memory `full
avg300≈30%`) — sshd and the k3s API included. oomd was running but monitored zero
cgroups, so nothing got killed. Now oomd kills the heaviest-swap cgroup when swap
crosses 80%; because k3s pods are pinned to no-swap and k3s.service holds ~47M vs
the gaming session's ~15G, the victim is always the GUI session and the service
plane is never touched.
