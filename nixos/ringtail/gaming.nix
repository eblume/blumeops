{ pkgs, ... }:

{
  # Steam
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
  };

  # Proton Experimental ships an accessibility bridge (xalia) that hangs during
  # game launch when AT-SPI is not running on the host. This host has no AT-SPI,
  # so disable xalia globally to avoid wedging iscriptevaluator.exe.
  environment.sessionVariables.PROTON_USE_XALIA = "0";

  # Gamescope — micro-compositor for game fullscreen/resolution management.
  # Use as Steam launch option: gamescope -W 2560 -H 1440 -f -- %command%
  programs.gamescope = {
    enable = true;
    capSysNice = true; # Allow gamescope to set realtime scheduling
  };
}
