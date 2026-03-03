#!/bin/bash
# Sync models from ConfigMap to Ollama server
# Runs as a sidecar in the ollama deployment, using the ollama CLI
set -euo pipefail

MODEL_LIST="${MODEL_LIST:-/config/models.txt}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
SYNC_INTERVAL="${SYNC_INTERVAL:-1800}"

export OLLAMA_HOST

echo "Syncing models from ${MODEL_LIST} via ollama CLI (host: ${OLLAMA_HOST})"

while true; do
    # Wait for ollama server to be ready
    echo "Waiting for Ollama API..."
    max_attempts=60
    attempt=0
    until ollama list > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            echo "Ollama not ready after ${max_attempts} attempts, will retry next cycle"
            sleep "$SYNC_INTERVAL"
            continue 2
        fi
        sleep 5
    done
    echo "Ollama is ready"

    # Get list of currently pulled models
    current=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || true)

    pulled=0
    skipped=0

    while IFS= read -r model || [[ -n "$model" ]]; do
        # Skip empty lines and comments
        [[ -z "$model" || "$model" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace
        model=$(echo "$model" | xargs)
        [[ -z "$model" ]] && continue

        # Check if model is already pulled (ollama list shows name:tag)
        if echo "$current" | grep -qF "$model"; then
            echo "Already present: $model"
            ((skipped++)) || true
        else
            echo "Pulling: $model"
            if ollama pull "$model"; then
                echo "Pulled: $model"
                ((pulled++)) || true
            else
                echo "Warning: Failed to pull $model" >&2
            fi
        fi
    done < "$MODEL_LIST"

    echo "Sync complete: $pulled pulled, $skipped already present"
    echo "Next sync in ${SYNC_INTERVAL}s"
    sleep "$SYNC_INTERVAL"
done
