#!/bin/sh
set -e

HTML_DIR="/usr/share/nginx/html"

# Check for required environment variable
if [ -z "$DOCS_RELEASE_URL" ]; then
    echo "Error: DOCS_RELEASE_URL environment variable is required"
    echo "Set it to the URL of the static site tarball to serve"
    exit 1
fi

echo "Downloading docs from: $DOCS_RELEASE_URL"

# Download the tarball
if ! curl -fsSL "$DOCS_RELEASE_URL" -o /tmp/docs.tar.gz; then
    echo "Error: Failed to download docs from $DOCS_RELEASE_URL"
    exit 1
fi

# Clear existing content and extract
rm -rf "${HTML_DIR:?}"/*
echo "Extracting docs to $HTML_DIR"
tar -xzf /tmp/docs.tar.gz -C "$HTML_DIR"
rm /tmp/docs.tar.gz

echo "Docs extracted successfully"
echo "Starting nginx..."

# Start nginx in foreground
exec nginx -g "daemon off;"
