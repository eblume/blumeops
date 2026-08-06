ringtail: `WLR_NO_HARDWARE_CURSORS=1` now actually reaches the sway session.
It had been configured via `programs.sway.extraSessionCommands` since
2026-02-18 and never applied — the running sway is home-manager's
`wayland.windowManager.sway` build, which never executes the NixOS module's
session wrapper. Moved to `environment.variables`, the mechanism the
`MOZ_ENABLE_WAYLAND` workaround already proved reaches the session.
