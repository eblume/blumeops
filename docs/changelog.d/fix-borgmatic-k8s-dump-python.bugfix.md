Fixed the borgmatic k8s sqlite dump helper to stream and clean up the staged
backup via `python3` instead of `cat`/`rm` — the horkos image ships no
coreutils, so the nightly dump produced a 0-byte file and aborted the whole
backup run. Also corrected `ansible_facts.ansible_env` → `ansible_facts.env`
(borgmatic + jellyfin roles), which broke provisioning after the injected-facts
deprecation cleanup.
