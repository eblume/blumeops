Enabled `systemd-oomd` swap-kill on ringtail (`ManagedOOMSwap=kill` on the root
slice, `SwapUsedLimit=80%`). A Crusader Kings 3 spike filled zram swap to ~95% and
froze the whole host in a multi-minute memory-pressure stall (PSI memory `full
avg300≈30%`) — sshd and the k3s API included. oomd was running but monitored zero
cgroups, so nothing got killed. Now oomd kills the heaviest-swap cgroup when swap
crosses 80%; because k3s pods are pinned to no-swap (so kubepods hold ~0 swap vs
the gaming session's ~15G), the victim is always a non-k3s process. Pod OOM
remains the job of each pod's memory limit plus the kernel cgroup OOM-killer.
Pressure-based root killing (`enableRootSlice`) was deliberately avoided — it
selects by memory footprint and could reap a pod before the game.
