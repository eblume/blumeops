#!/bin/bash
# Forgejo Runner entrypoint script
#
# Registers the runner on first start, then runs the daemon.
# State is persisted in /data so restarts don't re-register.

set -e

# Required environment variables
: "${FORGEJO_URL:?FORGEJO_URL is required (e.g., https://forge.ops.eblu.me)}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required (from Forgejo admin > Actions > Runners)}"

# Optional environment variables with defaults
RUNNER_NAME="${RUNNER_NAME:-forgejo-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-docker:docker://debian:bookworm-slim}"

# Registration file indicates runner is already registered
RUNNER_FILE="/data/.runner"

# Register if not already registered
if [ ! -f "$RUNNER_FILE" ]; then
    echo "Registering runner '${RUNNER_NAME}' with ${FORGEJO_URL}..."
    forgejo-runner register \
        --instance "${FORGEJO_URL}" \
        --token "${RUNNER_TOKEN}" \
        --name "${RUNNER_NAME}" \
        --labels "${RUNNER_LABELS}" \
        --no-interactive
    echo "Registration complete."
else
    echo "Runner already registered, skipping registration."
fi

# Start the runner daemon
echo "Starting forgejo-runner daemon..."
exec forgejo-runner daemon --config /etc/forgejo-runner/config.yaml
