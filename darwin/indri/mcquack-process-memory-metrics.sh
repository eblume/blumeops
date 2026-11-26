#!/bin/bash
# Collects the memory footprint of the largest processes for the
# node_exporter textfile collector. The unix exporter has no per-process
# view on macOS, so without this "who is holding the memory" needs ssh.

set -euo pipefail

OUTPUT_FILE="/opt/homebrew/var/node_exporter/textfile/process_memory.prom"
TEMP_FILE="${OUTPUT_FILE}.tmp"

{
cat << 'HEADER'
# HELP macos_process_footprint_bytes Memory footprint (top's MEM: resident + compressed + swapped) of the 15 largest processes, summed by command name
# TYPE macos_process_footprint_bytes gauge
HEADER

# top prints sizes as <n>[BKMG] with a trailing +/- change marker, and
# truncates command names; a name may contain spaces, so the size is the
# last field.
/usr/bin/top -l 1 -n 15 -o mem -stats command,mem 2>/dev/null | awk '
    seen {
        size = $NF; sub(/[+-]$/, "", size)
        unit = substr(size, length(size)); n = substr(size, 1, length(size) - 1) + 0
        mult = (unit == "G") ? 1073741824 : (unit == "M") ? 1048576 : (unit == "K") ? 1024 : 1
        $NF = ""; sub(/ +$/, ""); gsub(/["\\]/, "")
        if ($0 != "") total[$0] += n * mult
    }
    $1 == "COMMAND" { seen = 1 }
    END { for (c in total) printf "macos_process_footprint_bytes{command=\"%s\"} %.0f\n", c, total[c] }
'
} > "$TEMP_FILE"

mv "$TEMP_FILE" "$OUTPUT_FILE"
