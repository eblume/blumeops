# Weekly containerd image prune for ringtail's k3s store.
# Kubelet image GC only starts at 85% disk pressure (default
# imageGCHighThresholdPercent), so unused images accumulate in
# /var/lib/rancher/k3s/agent/containerd until the root NVMe is nearly full
# (eblume/blumeops#1887). This unit runs `k3s crictl rmi --prune` on a
# systemd timer, staggered away from the Monday 00:00 nix-gc, and writes the
# freed bytes as a textfile metric (containerd_prune_*) scraped by
# ringtail's Alloy. Metric only, no alert — the timestamp is the staleness
# witness: a failed run writes no file, so both a dead timer and a failing
# run show up as a stale timestamp.
{ config, pkgs, lib, ... }:

let
  metricDir = "/var/lib/containerd-prune";
  metricFile = "${metricDir}/containerd-prune.prom";

  # Sum of the byte sizes of the images in the CRI image store. The
  # go-template newline is a real newline in the template text — a written
  # \n stays literal through nix, shell and go-template, gloms the sizes
  # into one token and silently breaks the sum. The CRI Image proto's Size
  # field is bytes. set -euo pipefail makes a failed `crictl images` fail
  # the run (the pipeline via pipefail), so a bad inventory never writes a
  # bogus metric.
  prune = pkgs.writeShellScript "containerd-image-prune" ''
    set -euo pipefail
    export PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.mawk}/bin:${pkgs.k3s}/bin:$PATH

    sum_images() {
      k3s crictl images --output go-template --template '{{range .Images}}{{ .Size }}
  {{end}}' | awk '{ s += $1 } END { print s + 0 }'
    }

    before=$(sum_images)
    # The rmi output (the removed image refs) is the journal record of what
    # was freed.
    k3s crictl rmi --prune
    after=$(sum_images)
    freed=$((before - after))
    if [ "$freed" -lt 0 ]; then freed=0; fi
    echo "containerd image prune: freed $freed bytes (before=$before after=$after)"

    ts=$(date +%s)
    tmp="${metricDir}/containerd-prune.prom.tmp"
    {
      echo "# HELP containerd_prune_bytes Bytes of unused container images removed by the last containerd-image-prune run"
      echo "# TYPE containerd_prune_bytes gauge"
      echo "containerd_prune_bytes $freed"
      echo "# HELP containerd_prune_timestamp_seconds Unix time the last containerd-image-prune run completed"
      echo "# TYPE containerd_prune_timestamp_seconds gauge"
      echo "containerd_prune_timestamp_seconds $ts"
    } >"$tmp"
    mv -f "$tmp" ${metricFile}
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${metricDir} 0755 root root -"
  ];

  systemd.services.containerd-image-prune = {
    description = "Weekly containerd image prune for the k3s store";
    restartIfChanged = false;
    # Skip cleanly (condition, not failure) when the k3s containerd socket
    # is not up — e.g. a run racing a k3s restart.
    unitConfig.ConditionPathExists = "/run/k3s/containerd/containerd.sock";
    after = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${prune}";
      # Deleting tens of GB of image blobs plus the content GC outlives the
      # 90s oneshot default.
      TimeoutStartSec = "30min";
    };
  };

  systemd.timers.containerd-image-prune = {
    description = "Weekly containerd image prune for the k3s store";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Thursday 04:00 (ringtail local time, not UTC), staggered away from
      # the Monday 00:00 nix-gc.
      OnCalendar = "Thu *-*-* 04:00:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
