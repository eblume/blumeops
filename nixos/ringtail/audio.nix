{ pkgs, ... }:

let
  # Edifier R1700BTs desk speakers. Their left/right are physically wired
  # swapped and can't be moved, so the channels are crossed in software.
  edifierMac = "60:F4:3A:40:60:9B";
in
{
  # PipeWire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

    # A WirePlumber smart filter: any stream headed for the Edifier sink is
    # routed through this filter-chain first, which feeds its left input to
    # the right output and vice versa. It hangs off the speaker's own sink
    # (no separate "swapped" device to select, nothing left over when the
    # speakers are off). A node-level audio.position rule on the bluez sink
    # does not work: the A2DP node keeps the codec's channel map.
    extraConfig.pipewire."60-edifier-lr-swap" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "EDIFIER R1700BTs (L/R swapped)";
            "media.name" = "EDIFIER R1700BTs (L/R swapped)";
            "filter.graph" = {
              nodes = [
                { type = "builtin"; name = "left"; label = "copy"; }
                { type = "builtin"; name = "right"; label = "copy"; }
              ];
              inputs = [ "left:In" "right:In" ];
              outputs = [ "right:Out" "left:Out" ];
            };
            "capture.props" = {
              "node.name" = "edifier_lr_swap";
              "media.class" = "Audio/Sink";
              "audio.position" = [ "FL" "FR" ];
              "filter.smart" = true;
              "filter.smart.name" = "edifier-lr-swap";
              "filter.smart.target" = { "api.bluez5.address" = edifierMac; };
            };
            "playback.props" = {
              "node.name" = "edifier_lr_swap.out";
              "audio.position" = [ "FL" "FR" ];
              "node.passive" = true;
            };
          };
        }
      ];
    };
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # The speakers never initiate a connection, and BlueZ only retries after a
  # link loss, so power-on and reboots left them disconnected. Poll and
  # connect while they're paired and not connected. A deliberate disconnect
  # (e.g. to pair a phone) is undone within a minute; stop this unit for that.
  systemd.user.services.edifier-autoconnect = {
    description = "Keep the Edifier R1700BTs connected";
    unitConfig.ConditionUser = "eblume";
    wantedBy = [ "default.target" ];
    after = [ "pipewire.service" "wireplumber.service" ];
    path = [ pkgs.bluez pkgs.gnugrep ];
    script = ''
      while true; do
        if ! bluetoothctl info ${edifierMac} | grep -q "Connected: yes"; then
          bluetoothctl connect ${edifierMac} >/dev/null 2>&1 || true
        fi
        sleep 30
      done
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = 30;
    };
  };
}
