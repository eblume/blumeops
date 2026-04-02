{ pkgs, ... }:

{
  # Steam
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamescope — micro-compositor for game fullscreen/resolution management.
  # Use as Steam launch option: gamescope -W 2560 -H 1440 -f -- %command%
  programs.gamescope = {
    enable = true;
    capSysNice = true; # Allow gamescope to set realtime scheduling
  };
}
