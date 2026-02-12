#!/bin/sh
set -e

HTML_DIR="/usr/share/nginx/html"

# Check for required environment variable
if [ -z "$CV_RELEASE_URL" ]; then
    echo "Error: CV_RELEASE_URL environment variable is required"
    echo "Set it to the URL of the CV content tarball to serve"
    exit 1
fi

echo "Downloading CV content from: $CV_RELEASE_URL"

# Download the tarball
if ! curl -fsSL "$CV_RELEASE_URL" -o /tmp/cv.tar.gz; then
    echo "Error: Failed to download CV content from $CV_RELEASE_URL"
    exit 1
fi

# Clear existing content and extract
rm -rf "${HTML_DIR:?}"/*
echo "Extracting CV content to $HTML_DIR"
tar -xzf /tmp/cv.tar.gz -C "$HTML_DIR"
rm /tmp/cv.tar.gz

echo "CV content extracted successfully"
echo "Starting nginx..."

# Start nginx in foreground
exec nginx -g "daemon off;"
