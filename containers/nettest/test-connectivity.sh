#!/bin/ash
# shellcheck shell=dash
# Network connectivity test script for blumeops
# Tests access to tailnet services from within the container

set -e

echo "========================================"
echo "BlumeOps Network Connectivity Test"
echo "========================================"
echo ""
echo "Timestamp: $(date -Iseconds)"
echo "Hostname: $(hostname)"
echo ""

# Test targets
FORGE_HOST="forge.ops.eblu.me"
REGISTRY_HOST="registry.ops.eblu.me"

test_dns() {
    local host="$1"
    echo "--- DNS: $host ---"
    if nslookup "$host" 2>/dev/null; then
        echo "DNS: OK"
        return 0
    else
        echo "DNS: FAILED"
        return 1
    fi
}

test_https() {
    local url="$1"
    local name="$2"
    echo ""
    echo "--- HTTPS: $name ---"
    echo "URL: $url"

    # Try to fetch with verbose output
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>&1) || true

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ] || [ "$http_code" = "302" ]; then
        echo "HTTP Status: $http_code"
        echo "Result: OK (service reachable)"
        return 0
    elif [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
        echo "HTTP Status: $http_code"
        echo "Result: OK (service reachable, status $http_code)"
        return 0
    else
        echo "HTTP Status: $http_code"
        echo "Result: FAILED (could not connect)"
        return 1
    fi
}

test_registry_api() {
    local host="$1"
    echo ""
    echo "--- Registry API: $host ---"

    # Try to query the registry API
    response=$(curl -sf --max-time 10 "https://$host/v2/_catalog" 2>/dev/null) || true

    if [ -n "$response" ]; then
        echo "Response: $response"
        repo_count=$(echo "$response" | jq -r '.repositories | length' 2>/dev/null) || repo_count="unknown"
        echo "Repository count: $repo_count"
        echo "Result: OK"
        return 0
    else
        echo "Result: FAILED (no response from /v2/_catalog)"
        return 1
    fi
}

echo "========================================"
echo "Testing DNS Resolution"
echo "========================================"
dns_ok=0
test_dns "$FORGE_HOST" && dns_ok=$((dns_ok + 1)) || true
echo ""
test_dns "$REGISTRY_HOST" && dns_ok=$((dns_ok + 1)) || true

echo ""
echo "========================================"
echo "Testing HTTPS Connectivity"
echo "========================================"
https_ok=0
test_https "https://$FORGE_HOST" "Forgejo" && https_ok=$((https_ok + 1)) || true
test_https "https://$REGISTRY_HOST/v2/" "Zot Registry" && https_ok=$((https_ok + 1)) || true

echo ""
echo "========================================"
echo "Testing Registry API"
echo "========================================"
api_ok=0
test_registry_api "$REGISTRY_HOST" && api_ok=1 || true

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "DNS tests passed: $dns_ok/2"
echo "HTTPS tests passed: $https_ok/2"
echo "Registry API: $([ $api_ok -eq 1 ] && echo 'OK' || echo 'FAILED')"
echo ""

if [ "$dns_ok" -eq 2 ] && [ "$https_ok" -eq 2 ] && [ "$api_ok" -eq 1 ]; then
    echo "OVERALL: ALL TESTS PASSED"
    exit 0
else
    echo "OVERALL: SOME TESTS FAILED"
    exit 1
fi
