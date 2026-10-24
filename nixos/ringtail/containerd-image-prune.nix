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
{ config, pkgs, ... }:

let
  metricDir = "/var/lib/containerd-prune";
  metricFile = "${metricDir}/containerd-prune.prom";

  # The k3s containerd store trees the measurement covers: the per-image
  # content blobs (compressed, deduplicated) and the overlayfs snapshotter
  # tree (unpacked, deduplicated — the largest share of the disk `rmi
  # --prune` frees; the per-image CRI sizes never see it).
  prune = pkgs.writeShellScript "containerd-image-prune" ''
    set -euo pipefail
    export PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${config.services.k3s.package}/bin:$PATH

    trees=(
      /var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content
      /var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs
    )

    # containerd deletes snapshot files in the background, so du can see a
    # file vanish mid-walk: it exits 1 but still prints the total of what it
    # could see. That ENOENT is tolerated; any other du error, or a missing
    # tree, fails the run so a changed layout never writes a bogus metric.
    store_bytes() {
      local err total t
      for t in "''${trees[@]}"; do
        [ -d "$t" ] || { echo "containerd prune: store tree missing: $t" >&2; exit 1; }
      done
      err=$(mktemp)
      total=$(du -sbc -- "''${trees[@]}" 2>"$err" | tail -n1 | cut -f1) || true
      if grep -qv 'No such file or directory' "$err"; then
        cat "$err" >&2
        rm -f "$err"
        exit 1
      fi
      rm -f "$err"
      [ -n "$total" ] || { echo "containerd prune: du produced no total" >&2; exit 1; }
      echo "$total"
    }

    # containerd's async snapshot GC keeps deleting after rmi returns, so the
    # first post-prune sample can land mid-deletion. Sample until two reads
    # 30s apart agree (bounded; the last sample is used if it never settles).
    settled_store_bytes() {
      local prev cur
      prev=$(store_bytes)
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 30
        cur=$(store_bytes)
        if [ "$cur" = "$prev" ]; then echo "$cur"; return 0; fi
        prev=$cur
      done
      echo "containerd prune: store size still changing after 5 min; using last sample" >&2
      echo "$cur"
    }

    before=$(store_bytes)
    # The rmi output (the removed image refs) is the journal record of what
    # was freed. The per-image timeout must exceed crictl's 2s default, or
    # large image removals fail with DeadlineExceeded.
    k3s crictl --timeout=5m rmi --prune
    after=$(settled_store_bytes)
    freed=$((before - after))
    if [ "$freed" -lt 0 ]; then freed=0; fi
    echo "containerd image prune: freed $freed bytes (before=$before after=$after)"

    ts=$(date +%s)
    tmp="${metricDir}/containerd-prune.prom.tmp"
    {
      echo "# HELP containerd_prune_bytes Bytes of the k3s containerd store (content and snapshotter trees) freed by the last containerd-image-prune run"
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
      # Deleting tens of GB of image blobs, the content GC, and the settle
      # loop's repeated du walks outlive the 90s oneshot default.
      TimeoutStartSec = "60min";
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
