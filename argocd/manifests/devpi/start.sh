#!/bin/bash
set -e

SERVERDIR="${DEVPI_SERVERDIR:-/devpi}"
HOST="${DEVPI_HOST:-0.0.0.0}"
# Note: Can't use DEVPI_PORT - Kubernetes auto-sets it for service discovery
PORT="${DEVPI_LISTEN_PORT:-3141}"
OUTSIDE_URL="${DEVPI_OUTSIDE_URL:-}"

# Check if devpi is initialized
if [ ! -f "$SERVERDIR/.serverversion" ]; then
    echo "Initializing devpi server..."

    if [ -z "$DEVPI_ROOT_PASSWORD" ]; then
        echo "ERROR: DEVPI_ROOT_PASSWORD environment variable must be set for initialization"
        exit 1
    fi

    devpi-init --serverdir "$SERVERDIR" --root-passwd "$DEVPI_ROOT_PASSWORD"
    echo "Devpi initialized successfully"
fi

# Build command
CMD="devpi-server --serverdir $SERVERDIR --host $HOST --port $PORT"

if [ -n "$OUTSIDE_URL" ]; then
    CMD="$CMD --outside-url $OUTSIDE_URL"
fi

echo "Starting devpi-server..."
exec $CMD
