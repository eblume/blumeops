"""Pulumi program to manage tail8d86e.ts.net tailnet configuration.

This program manages:
- ACL policy (grants, SSH rules, tag owners, tests)
- Device tags for infrastructure classification

Devices are tagged based on their role:
- tag:homelab - Server infrastructure (indri, ringtail)
- tag:workstation - Development machines that can manage homelab (gilbert)
- tag:nas - Network-attached storage (sifaka)
- tag:blumeops - Resources managed by this IaC
- Service tags (grafana, forge, etc.) - Fine-grained service access control
"""

import hashlib

import pulumi
import pulumi_tailscale as tailscale
from pathlib import Path

# Read the HuJSON policy file
policy_path = Path(__file__).parent / "policy.hujson"
policy_content = policy_path.read_text()

# Compute policy hash for change tracking
policy_hash = hashlib.sha256(policy_content.encode()).hexdigest()[:12]

# Manage the ACL - this completely overwrites the tailnet's ACL policy
acl = tailscale.Acl(
    "tailnet-acl",
    acl=policy_content,
)

# ============== Device Tags ==============
# Manage tags for devices in the tailnet.
# Tags control access via the ACL policy in policy.hujson.

# indri - Mac Mini M1, primary homelab server
# Hosts forge, loki, zot registry, and the k8s control plane.
# Other services (grafana, kiwix, etc.) run in k8s with their own Tailscale devices.
indri = tailscale.get_device(name="indri.tail8d86e.ts.net")
indri_tags = tailscale.DeviceTags(
    "indri-tags",
    device_id=indri.node_id,
    tags=[
        "tag:homelab",  # Server role - allows SSH from workstations
        "tag:blumeops",  # Managed by this IaC
        # Service tags for services still hosted directly on indri
        "tag:forge",
        "tag:registry",  # Zot container registry
        "tag:flyio-target",  # Fly proxy routes through Caddy on indri
    ],
)

# NOTE: gilbert (MacBook Air M4) is NOT tagged via Pulumi
# Tagging a user-owned device converts it to a "tagged device" which loses
# user identity, breaking user-based SSH rules. gilbert remains user-owned
# so blume.erich@gmail.com can SSH to homelab via the ACL rules.

# sifaka - Synology NAS, backup target
# Homelab and workstations can access for backups
sifaka = tailscale.get_device(name="sifaka.tail8d86e.ts.net")
sifaka_tags = tailscale.DeviceTags(
    "sifaka-tags",
    device_id=sifaka.node_id,
    tags=[
        "tag:nas",  # NAS role - accessible by homelab and workstations
        "tag:blumeops",  # Managed by this IaC
    ],
)

# ringtail - NixOS gaming/compute workstation
# Managed by this IaC after initial bootstrap via auth key.
ringtail = tailscale.get_device(name="ringtail.tail8d86e.ts.net")
ringtail_tags = tailscale.DeviceTags(
    "ringtail-tags",
    device_id=ringtail.node_id,
    tags=[
        "tag:homelab",  # Server role - allows SSH from workstations and homelab peers
        "tag:blumeops",  # Managed by this IaC
        "tag:factorio",  # Hosts the shared Factorio server; lets autogroup:shared
        # guests reach udp:34197 here (and nothing else). See policy.hujson.
    ],
)

# ============== Auth Keys ==============

# Auth key for Fly.io proxy container (public reverse proxy)
flyio_key = tailscale.TailnetKey(
    "flyio-proxy-key",
    reusable=True,
    ephemeral=True,
    preauthorized=True,
    tags=["tag:flyio-proxy"],
    expiry=7776000,  # 90 days
)

# Auth key for the agent pod's (talos's) Tailscale sidecar.
# The sidecar joins the tailnet as its OWN device (tag:agent) so the agent pod's
# egress to indri (forge push, heph sync) is gated by the tag:agent ACL grant —
# distinct from ringtail's tag:homelab node identity, which a shared-host agent
# would otherwise inherit. This is the credential that makes device isolation
# real. See docs/explanation/agent-containerization.md.
agent_key = tailscale.TailnetKey(
    "agent-key",
    reusable=True,  # a Deployment pod re-auths on restart
    ephemeral=True,  # node is removed when the pod goes away
    preauthorized=True,
    tags=["tag:agent"],
    expiry=7776000,  # 90 days
)

# ============== Exports ==============
pulumi.export("acl_id", acl.id)
pulumi.export("policy_hash", policy_hash)
pulumi.export("flyio_authkey", flyio_key.key)
pulumi.export("agent_authkey", agent_key.key)

pulumi.export("indri_device_id", indri.node_id)
pulumi.export("indri_tags", indri_tags.tags)

pulumi.export("sifaka_device_id", sifaka.node_id)
pulumi.export("sifaka_tags", sifaka_tags.tags)

pulumi.export("ringtail_device_id", ringtail.node_id)
pulumi.export("ringtail_tags", ringtail_tags.tags)
