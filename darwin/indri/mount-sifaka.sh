#!/bin/sh
# Mounts the five sifaka SMB shares with indri consumers (backups, photos,
# shower, allisonflix, music) onto /Volumes/<share> - the AutoMounter
# replacement. Runs from the mcquack.eblume.sifaka-mounter LaunchAgent at
# load and every 60 s.
#
# The password comes from the login Keychain via osascript `mount volume`
# (the NetFS path Finder uses): no credential enters this repo, argv or the
# unit log. When the entry is MISSING osascript shows a GUI credential
# prompt - the timeout below kills it, so a missing credential surfaces as
# sifaka_share_mounted{share=...} 0 in Prometheus, never a prompt.

set -u

LC_MNT='eblume@sifaka._smb._tcp.local'
SHARES='backups photos shower allisonflix music'
TIMEOUT_SECS=30
OUT_DIR='/opt/homebrew/var/node_exporter/textfile'
OUTPUT_FILE="$OUT_DIR/sifaka.prom"
TEMP_FILE="$OUTPUT_FILE.tmp"
# launchd never overlaps a one-shot job with itself (no KeepAlive, no
# ThrottleInterval), so at most one run is ever in progress; the per-share
# timeout bounds a full run to 5 * TIMEOUT_SECS.
# Per-mount timeout. macOS ships no coreutils timeout, and the credential
# dialog (the real blocker) lives in the osascript child - so run the
# child, kill it on alarm, timeout exit code 124.
run_with_timeout() {
  secs="$1"
  shift
  TT_SECS="$secs" /usr/bin/perl -e '
    use POSIX ":sys_wait_h";
    my ($rc, $prev);
    $prev{CHLD} = $SIG{CHLD};
    $SIG{CHLD} = "DEFAULT";
    $pid = fork();
    exit 127 unless defined $pid;
    exec @ARGV if $pid == 0;
    exit 127 if $pid == 0;
    $SIG{CHLD} = $prev{CHLD};
    $SIG{ALRM} = sub { kill "TERM" => $pid; exit 124 };
    alarm $ENV{TT_SECS};
    waitpid($pid, 0);
    $rc = $? >> 8;
    exit 124 if $? & 0x7f;
    exit $rc;
  ' "$@"
}

# mount(8) prints "device on /mountpoint (type, ...)" - the mount point is
# column 3. Absolute path: mount lives in /sbin, which the agent's PATH
# doesn't carry.
is_mounted() { /sbin/mount | awk -v v="$1" '$3 == v { found = 1 } END { exit found ? 0 : 1 }'; }

# execvp can't reach a shell function, so osascript's argv goes straight
# through run_with_timeout; the URL is quoted for the AppleScript string.
for share in $SHARES; do
  if is_mounted "/Volumes/$share"; then
    continue
  fi
  echo "mounting $share (smb://$LC_MNT/$share)"
  if out=$(run_with_timeout "$TIMEOUT_SECS" /usr/bin/osascript -e "mount volume \"smb://$LC_MNT/$share\"" 2>&1); then
    if is_mounted "/Volumes/$share"; then
      echo "mounted $share"
    else
      echo "mount of $share reported success but /Volumes/$share is not mounted: $out" >&2
    fi
  else
    echo "mount of $share failed within ${TIMEOUT_SECS}s (keychain entry missing or sifaka unreachable) - skipping until next interval; visible as sifaka_share_mounted{share=\"$share\"} 0" >&2
  fi
done

# textfile metric for alloy's node_exporter replacement - same dir and
# atomic .tmp + mv pattern as the mcquack.*-metrics collectors.
mkdir -p "$OUT_DIR"
{
  echo '# HELP sifaka_share_mounted 1 when the share is mounted at /Volumes/<share>'
  echo '# TYPE sifaka_share_mounted gauge'
  for share in $SHARES; do
    if is_mounted "/Volumes/$share"; then
      echo "sifaka_share_mounted{share=\"$share\"} 1"
    else
      echo "sifaka_share_mounted{share=\"$share\"} 0"
    fi
  done
  echo "sifaka_share_mounted_updated_timestamp $(/bin/date +%s)"
} > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE" || {
  echo "failed to write $OUTPUT_FILE" >&2
  exit 1
}
