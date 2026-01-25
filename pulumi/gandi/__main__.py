"""Pulumi program to manage eblu.me DNS via Gandi LiveDNS.

This program manages DNS records for blumeops infrastructure:
- Wildcard record for *.ops.eblu.me pointing to indri's Tailscale IP
- indri hosts Caddy as the reverse proxy for all services
- This allows services to be accessed via real DNS names while remaining
  tailnet-only (Tailscale IPs are not publicly routable)

Authentication:
  Set GANDI_PERSONAL_ACCESS_TOKEN environment variable.
  See README.md for PAT management instructions.
"""

import os
import socket

import pulumi
import pulumiverse_gandi as gandi

# Get configuration
config = pulumi.Config()
domain = config.require("domain")  # eblu.me
subdomain = config.require("subdomain")  # ops

# Resolve indri's Tailscale IP dynamically via MagicDNS
# This script runs on the tailnet, so we can resolve the hostname directly.
# indri hosts Caddy, which reverse-proxies all services.
# Break-glass: set BLUMEOPS_REVERSE_PROXY_IP env var to override DNS resolution
REVERSE_PROXY_HOST = "indri.tail8d86e.ts.net"
tailscale_ip = os.environ.get("BLUMEOPS_REVERSE_PROXY_IP") or socket.gethostbyname(
    REVERSE_PROXY_HOST
)

# Wildcard A record for *.ops.eblu.me
# Points to indri's Tailscale IP, which is only routable within the tailnet.
# This allows containers and other systems to resolve real DNS names
# while keeping services private to the tailnet.
wildcard_record = gandi.livedns.Record(
    "ops-wildcard",
    zone=domain,
    name=f"*.{subdomain}",
    type="A",
    ttl=300,
    values=[tailscale_ip],
)

# Base subdomain record (ops.eblu.me) - same IP
base_record = gandi.livedns.Record(
    "ops-base",
    zone=domain,
    name=subdomain,
    type="A",
    ttl=300,
    values=[tailscale_ip],
)

# ============== Exports ==============
pulumi.export("domain", domain)
pulumi.export("wildcard_fqdn", f"*.{subdomain}.{domain}")
pulumi.export("base_fqdn", f"{subdomain}.{domain}")
pulumi.export("target_ip", tailscale_ip)
