#!/bin/bash
# Restarts fseventsd when its memory footprint passes THRESHOLD_BYTES.
# Runs as root (it signals a system daemon).

set -euo pipefail

THRESHOLD_BYTES=$((2 * 1024 * 1024 * 1024))
RESTART_HOLDOFF_SECONDS=3600

TEXTFILE_DIR=/opt/homebrew/var/node_exporter/textfile
OUTPUT_FILE="$TEXTFILE_DIR/fseventsd-watchdog.prom"
STATE_DIR=/var/db/mcquack.fseventsd-watchdog
STATE_FILE="$STATE_DIR/state"

restarts_total=0
last_restart=0
restart_ok=0
if [[ -f "$STATE_FILE" ]]; then
    restarts_total=$(sed -n 's/^restarts_total=//p' "$STATE_FILE" | head -n1)
    last_restart=$(sed -n 's/^last_restart=//p' "$STATE_FILE" | head -n1)
    restart_ok=$(sed -n 's/^last_restart_ok=//p' "$STATE_FILE" | head -n1)
fi
[[ "$restarts_total" =~ ^[0-9]+$ ]] || restarts_total=0
[[ "$last_restart" =~ ^[0-9]+$ ]] || last_restart=0
[[ "$restart_ok" =~ ^[01]$ ]] || restart_ok=0

write_state() {
    mkdir -p "$STATE_DIR"
    local state_tmp="$STATE_FILE.tmp"
    {
        printf 'restarts_total=%s\n' "$restarts_total"
        printf 'last_restart=%s\n' "$last_restart"
        printf 'last_restart_ok=%s\n' "$restart_ok"
    } > "$state_tmp"
    mv "$state_tmp" "$STATE_FILE"
}

# top's MEM column is resident + compressed + swapped, which is the leaked
# part; RSS stays small because the leaked pages are swapped out.
footprint=0
up=0
pid=$(/usr/bin/pgrep -x fseventsd | /usr/bin/head -n1 || true)
if [[ -n "$pid" ]]; then
    up=1
    footprint=$(/usr/bin/top -l 1 -pid "$pid" -stats command,mem 2>/dev/null | /usr/bin/awk '
        $1 == "COMMAND" { seen = 1; next }
        seen && NF {
            size = $NF; sub(/[+-]$/, "", size)
            unit = substr(size, length(size)); n = substr(size, 1, length(size) - 1)
            if (n !~ /^[0-9.]+$/) next
            mult = (unit == "G") ? 1073741824 : (unit == "M") ? 1048576 : (unit == "K") ? 1024 : (unit == "B") ? 1 : 0
            if (mult == 0) next
            bytes = n * mult; found = 1
        }
        END { if (found) printf "%.0f\n", bytes }
    ') || footprint=""
    if [[ -z "$footprint" ]]; then
        printf 'error: could not parse fseventsd footprint from top - not restarting, textfile not written\n' >&2
        exit 1
    fi
fi

now=$(date +%s)
held=0
restart=0
if (( footprint > THRESHOLD_BYTES )); then
    if (( last_restart <= now && now - last_restart < RESTART_HOLDOFF_SECONDS )); then
        held=1
        printf 'warning: fseventsd footprint %s bytes is over threshold but the last restart was under %s s ago - holding\n' \
            "$footprint" "$RESTART_HOLDOFF_SECONDS" >&2
    else
        restart=1
    fi
fi

# The restart is recorded before the kill, so a failed state write can never
# leave the hourly guard disengaged.
if (( restart )); then
    restarts_total=$((restarts_total + 1))
    last_restart=$now
fi
write_state || {
    printf 'error: could not record the restart in %s - not restarting\n' "$STATE_FILE" >&2
    exit 1
}

# A kill that is ignored leaves the old pid running, so success is a new pid,
# not a running one.
if (( restart )); then
    printf 'restarting fseventsd: footprint %s bytes over threshold %s bytes\n' \
        "$footprint" "$THRESHOLD_BYTES" >&2
    old_pid=$pid
    if ! /usr/bin/killall fseventsd; then
        printf 'warning: killall fseventsd failed - the restart is recorded, the guard will retry after the holdoff\n' >&2
    fi
    sleep 5
    new_pid=$(/usr/bin/pgrep -x fseventsd | /usr/bin/head -n1 || true)
    if [[ -n "$new_pid" && "$new_pid" != "$old_pid" ]]; then
        restart_ok=1
    else
        restart_ok=0
        printf 'warning: fseventsd pid %s unchanged or absent 5 s after restart - launchd keep-alive did not replace it\n' \
            "$old_pid" >&2
    fi
    write_state || printf 'warning: could not record the restart outcome in %s\n' "$STATE_FILE" >&2
fi

TEMP_FILE="${OUTPUT_FILE}.tmp"
cat > "$TEMP_FILE" << PROM
# HELP macos_fseventsd_footprint_bytes Memory footprint (top's MEM: resident + compressed + swapped) of fseventsd, as last checked
# TYPE macos_fseventsd_footprint_bytes gauge
macos_fseventsd_footprint_bytes $footprint
# HELP macos_fseventsd_watchdog_threshold_bytes Footprint above which the watchdog restarts fseventsd
# TYPE macos_fseventsd_watchdog_threshold_bytes gauge
macos_fseventsd_watchdog_threshold_bytes $THRESHOLD_BYTES
# HELP macos_fseventsd_watchdog_restarts_total fseventsd restarts issued by the watchdog (persisted across runs)
# TYPE macos_fseventsd_watchdog_restarts_total counter
macos_fseventsd_watchdog_restarts_total $restarts_total
# HELP macos_fseventsd_watchdog_last_restart_timestamp_seconds Unix time of the watchdog's last restart (0 if never)
# TYPE macos_fseventsd_watchdog_last_restart_timestamp_seconds gauge
macos_fseventsd_watchdog_last_restart_timestamp_seconds $last_restart
# HELP macos_fseventsd_watchdog_held 1 if the footprint is over threshold but the hourly restart guard held the restart
# TYPE macos_fseventsd_watchdog_held gauge
macos_fseventsd_watchdog_held $held
# HELP macos_fseventsd_watchdog_last_restart_ok Outcome of the watchdog's most recent restart: 1 if it brought up a new fseventsd pid, 0 if the pid was unchanged or absent (0 before any restart)
# TYPE macos_fseventsd_watchdog_last_restart_ok gauge
macos_fseventsd_watchdog_last_restart_ok $restart_ok
# HELP macos_fseventsd_up 1 if an fseventsd process is running
# TYPE macos_fseventsd_up gauge
macos_fseventsd_up $up
PROM
mv "$TEMP_FILE" "$OUTPUT_FILE"
