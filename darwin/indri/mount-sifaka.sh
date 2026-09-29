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
# The lock makes the runs overlap-free; a killed in-flight run is
# interrupted, not retried within the same minute.

set -u

LC_MNT='eblume@sifaka._smb._tcp.local'
SHARES='backups photos shower allisonflix music'
LOCK_FILE='/tmp/sifaka-mounter.lock'
TIMEOUT_SECS=30
OUT_DIR='/opt/homebrew/var/node_exporter/textfile'
OUTPUT_FILE="$OUT_DIR/sifaka.prom"
TEMP_FILE="$OUTPUT_FILE.tmp"
# shellcheck disable=SC2034 # documented for operators; kept for context
SCRIPT_USER='erichblume'

# Single in-flight run: a stale lock from a killed osascript means the
# previous run is already dead; never touch a live one.
exec 9>"$LOCK_FILE" || { echo "cannot open $LOCK_FILE" >&2; exit 1; }
if ! flock -n 9; then
  echo "previous run still in progress, skipping"
  exit 0
fi

# Per-mount timeout. macOS ships no coreutils timeout and launchd's
# ExitTimeOut can't fire while the process tree holds a GUI session; the
# perl SIGALRM pattern runs the osascript (which owns the dialog) in a
# child and kills it, timeout exit code 124.
run_with_timeout() {
  /usr/bin/perl -e '
    use POSIX ":sys_wait_h";
    local $SIG{ALRM} = sub { kill "TERM" => $pid; exit 124 };
    alarm shift;
    my $pid = fork() or do { exec @ARGV or exit 127 };
    waitpid($pid, 0);
    my $rc = $? >> 8;
    exit 124 if $? & 0x7f;
    exit $rc;
  ' "$@"
}

# mount | awk '$2 == "/Volumes/x"' matches the mount point column only.
is_mounted() { mount | awk -v v="$1" '$2 == v { found = 1 } END { exit found ? 0 : 1 }'; }

# osascript needs the mount URL quoted; the URL contains no single quotes.
mount_share() {
  /usr/bin/osascript -e "mount volume \"smb://$LC_MNT/$1\"" 2>&1
}

for share in $SHARES; do
  if is_mounted "/Volumes/$share"; then
    continue
  fi
  echo "mounting $share (smb://$LC_MNT/$share)"
  if out=$(run_with_timeout "$TIMEOUT_SECS" mount_share "$share"); then
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
