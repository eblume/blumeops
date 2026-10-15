# Shared plumbing for ringtail's two hephd spokes (agent-heph-spoke.nix,
# heph-eblume.nix): the same hub and the same nix-store heph package (the
# flake's hephaestus input, reaching modules as `hephPkg`), different
# identities and token stores. Plain import
# (`import ./heph-common.nix { inherit pkgs lib; }`), not a module.
{ pkgs, lib }:
rec {
  hubUrl = "http://indri.tail8d86e.ts.net:8787";
  issuer = "https://authentik.ops.eblu.me/application/o/heph/";
  # Adopted by every spoke so all spokes operate on the same nodes; only the
  # login identity varies. Not a secret (it appears in HLCs).
  ownerId = "01KT4MYCG6Q45N3MJ665V53AMM";

  # Desktop-spoke binaries; the agent spoke has no use for the GUI bins.
  desktopBins = [ "heph" "hephd" "heph-tui" "heph-quickadd" ];

  # Shims that put the store package's heph bins (off the session PATH) on the
  # session PATH via the home-manager profile. No LD_LIBRARY_PATH export: the
  # store's heph-quickadd is wrapped with its GUI lib path, and heph-tui must
  # not get one (it shells out to nvim, which would inherit it).
  mkShims = { bins, binDir }:
    pkgs.buildEnv {
      name = "heph-shims";
      paths = map (b: pkgs.writeShellScriptBin b ''exec ${binDir}/${b} "$@"'') bins;
    };

  # Raises the quick-capture popover; one process per capture, since Wayland
  # cannot hide a window (no persistent agent possible).
  mkQuickaddLauncher = { binDir }:
    pkgs.writeShellScriptBin "heph-quickadd-popover" ''
      exec ${binDir}/heph-quickadd popover "$@"
    '';

  # System-scope spoke service for a nix-store hephd (the agent spoke).
  #
  # System scope means no XDG_RUNTIME_DIR, so hephd binds the
  # ~/.local/share/heph fallback socket — right for env-less services, wrong
  # for interactive users (their spoke belongs in the USER manager;
  # heph-eblume.nix).
  mkSpokeStack = { prefix, user, group, spokeExec, who }:
    {
      services."${prefix}-spoke" = {
        description = "heph spoke for ${who} (hephd synced to the indri hub)";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        startLimitIntervalSec = 0;
        serviceConfig = {
          User = user;
          Group = group;
          ExecStart = spokeExec;
          Restart = "always";
          RestartSec = 10;
          StandardOutput = "journal";
          StandardError = "journal";
          NoNewPrivileges = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
        };
      };
    };
}
