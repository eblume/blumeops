services-check: the borgmatic-metrics and zot-metrics checks used launchctl
labels missing the `.eblume` segment; `launchctl list` is exact-match, so
they never matched the real agents. Both checks now use the full
`mcquack.eblume.*` labels.
