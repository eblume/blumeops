instance-config-out-of-components aspect: an invariant that component source in talos and
horkos (src/, prompts/, and app/) ships no instance values — eblu.me hostnames, the tailnet
hostname, the owner name `eblume`, or 1Password `op://` references — with comments
(whole-line and trailing), docstrings, and test files exempt; TS prompt strings in template
literals are scanned. A narrower durable complement to the per-repo scripts/instance-refs
linters, which stay; ASPECT.md lists the coverage delta (eblume/blumeops#1809).
