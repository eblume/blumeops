sifaka-mounter: call `/sbin/mount` by absolute path — the agent's PATH has no `/sbin`, so every mount check failed and all five shares reported `sifaka_share_mounted 0`.
