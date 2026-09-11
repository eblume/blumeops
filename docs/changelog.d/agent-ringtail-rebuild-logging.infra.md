ringtail-rebuild: capture nixos-rebuild output in the per-sha apply log (journal
follow in the wrapper) and stream it live into the forge run log, plus --no-block
on the wrapper's systemd-run — a run self-killed by the rebuild it applies now
leaves a diagnostic record (#980).
