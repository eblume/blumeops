agent-repo-access now also reconciles the forge→horkos release webhook:
repos with `release_hook` in repos.json get a push+tag-create hook at
horkos.ops.eblu.me, and the horkos pod gains an ExternalSecret for the
shared signing secret (eblume/horkos#17 step 2).
