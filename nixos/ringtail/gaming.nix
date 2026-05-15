{ pkgs, ... }:

{
  # Steam
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # Proton Experimental ships an accessibility bridge (xalia) that hangs during
  # game launch when AT-SPI is not running on the host. This host has no AT-SPI,
  # so disable xalia globally to avoid wedging iscriptevaluator.exe.
  environment.sessionVariables.PROTON_USE_XALIA = "0";

  # Subnautica 2 pre-launch wrapper. SN2 (UE5) writes Saved/running.dat as a
  # "currently running" lockfile. If the prior session exited uncleanly (SIGKILL
  # via Steam's Stop button, crash, etc.), the file persists and on next launch
  # SN2 pops up an invisible (0x0-sized) Error dialog ("Your game might not have
  # exited correctly last time...") that the GameThread blocks on forever —
  # observable only as a black screen with a spinning loader. This wrapper
  # removes the stale lockfiles before exec'ing the actual game command.
  # Use as Steam launch option for Subnautica 2:
  #   sn2-prelaunch %command%
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "sn2-prelaunch" ''
      saved="/mnt/games/SteamLibrary/steamapps/compatdata/1962700/pfx/drive_c/users/steamuser/AppData/Local/Subnautica2/Saved"
      rm -f "$saved/running.dat" "$saved/beforelobby.dat"
      exec "$@"
    '')
  ];

  # Gamescope — micro-compositor for game fullscreen/resolution management.
  # Use as Steam launch option: gamescope -W 2560 -H 1440 -f -- %command%
  programs.gamescope = {
    enable = true;
    capSysNice = true; # Allow gamescope to set realtime scheduling
  };
}
