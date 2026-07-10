"""Pulumi program to manage eblu.me DNS via Gandi LiveDNS.

This program manages DNS records for blumeops infrastructure:
- Wildcard record for *.ops.eblu.me pointing to indri's Tailscale IP
- indri hosts Caddy as the reverse proxy for all services
- This allows services to be accessed via real DNS names while remaining
  tailnet-only (Tailscale IPs are not publicly routable)

Authentication:
  Set GANDI_PERSONAL_ACCESS_TOKEN environment variable.
  See docs/how-to/configuration/rotate-gandi-pat.md for PAT management.
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

# ringtail hosts the Factorio server (UDP game protocol, not HTTP — it bypasses
# Caddy on indri entirely). See the factorio_record below for why this is a
# CNAME to the MagicDNS name rather than a pinned A record.
FACTORIO_HOST = "ringtail.tail8d86e.ts.net"

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

# Exact CNAME for factorio.ops.eblu.me -> ringtail's MagicDNS name.
#
# NOT an A record: Tailscale assigns a *shared* node a different 100.x address
# in each guest's tailnet when the owner-tailnet IP collides with something the
# guest already has (ringtail is .77 here but was remapped to .76 in a guest's
# tailnet). A pinned A record publishes one owner-tailnet IP that guests can't
# route, so it times out for them. A CNAME instead delegates resolution to each
# client's own MagicDNS, which returns the address correct for *their* view.
#
# Caveat: this resolves only for clients that forward lookups through the
# Tailscale resolver (MagicDNS names aren't in public DNS). A guest on a
# strict split-DNS setup should connect to ringtail.tail8d86e.ts.net directly.
# An exact name still beats the *.ops wildcard, so this doesn't hit Caddy.
factorio_record = gandi.livedns.Record(
    "factorio-ops",
    zone=domain,
    name=f"factorio.{subdomain}",  # -> factorio.ops
    type="CNAME",
    ttl=300,
    values=[f"{FACTORIO_HOST}."],
)

# ============== Public Services (Fly.io proxy) ==============
# CNAME records pointing public subdomains to Fly.io for reverse proxying
# back to the tailnet. See docs/how-to/expose-service-publicly.md

# Apex (eblu.me) landing page. A CNAME is illegal at the zone apex, so the
# apex is pinned to Fly's ingress IPs directly instead of the CNAME the
# subdomains use. Unlike the subdomains' `fly.dev` CNAME (which publishes all
# three of the app's dedicated IPv6 addresses), the apex uses the single
# canonical ingress pair that `fly certs setup eblu.me` recommends — the shared
# IPv4 (Fly routes it by SNI + the eblu.me cert) and the primary ingress IPv6.
# Fly's cert validation flags the other two IPv6 addresses as "not pointing to
# your app", so listing all three leaves the apex cert unverified. If the Fly
# IPs ever change, re-check `fly certs setup eblu.me` and update them here.
FLY_INGRESS_IPV4 = "66.241.124.93"
FLY_INGRESS_IPV6 = ["2a09:8280:1::d1:8ef:2"]

apex_a = gandi.livedns.Record(
    "apex-a",
    zone=domain,
    name="@",
    type="A",
    ttl=300,
    values=[FLY_INGRESS_IPV4],
)

apex_aaaa = gandi.livedns.Record(
    "apex-aaaa",
    zone=domain,
    name="@",
    type="AAAA",
    ttl=300,
    values=FLY_INGRESS_IPV6,
)

# www.eblu.me is a normal subdomain — CNAME to Fly like the others.
www_public = gandi.livedns.Record(
    "www-public",
    zone=domain,
    name="www",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)

docs_public = gandi.livedns.Record(
    "docs-public",
    zone=domain,
    name="docs",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)

cv_public = gandi.livedns.Record(
    "cv-public",
    zone=domain,
    name="cv",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)

forge_public = gandi.livedns.Record(
    "forge-public",
    zone=domain,
    name="forge",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)

shower_public = gandi.livedns.Record(
    "shower-public",
    zone=domain,
    name="shower",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)

# ============== Exports ==============
pulumi.export("domain", domain)
pulumi.export("wildcard_fqdn", f"*.{subdomain}.{domain}")
pulumi.export("base_fqdn", f"{subdomain}.{domain}")
pulumi.export("target_ip", tailscale_ip)
pulumi.export("factorio_fqdn", f"factorio.{subdomain}.{domain}")
pulumi.export("factorio_cname", f"{FACTORIO_HOST}.")
pulumi.export("apex_fqdn", domain)
pulumi.export("www_public_fqdn", f"www.{domain}")
pulumi.export("docs_public_fqdn", f"docs.{domain}")
pulumi.export("cv_public_fqdn", f"cv.{domain}")
pulumi.export("forge_public_fqdn", f"forge.{domain}")
pulumi.export("shower_public_fqdn", f"shower.{domain}")
