talos-data session state now has its own never-pruned borgmatic config
(`talos-data-*` prefix, no keep_* keys) run alongside the main config; the
main config's prune is scoped to `indri-*`; collector gauges scoped to the
main prefix so talos archives can't mask a failed main backup.

Part of eblume/blumeops#1409.
