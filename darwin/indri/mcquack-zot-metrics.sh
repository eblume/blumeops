#!/bin/bash
# Collects Zot registry metrics for node_exporter textfile collector

set -euo pipefail

METRICS_URL="http://localhost:5050/v2/_catalog"
OUTPUT_FILE="/opt/homebrew/var/node_exporter/textfile/zot.prom"
TEMP_FILE="${OUTPUT_FILE}.tmp"

# Start output file with header
cat > "$TEMP_FILE" << 'HEADER'
# HELP zot_up Zot registry is up and responding
# TYPE zot_up gauge
HEADER

# Check if zot is up
if curl -sf "$METRICS_URL" > /dev/null 2>&1; then
    echo "zot_up 1" >> "$TEMP_FILE"
else
    echo "zot_up 0" >> "$TEMP_FILE"
fi

# Atomic move
mv "$TEMP_FILE" "$OUTPUT_FILE"
