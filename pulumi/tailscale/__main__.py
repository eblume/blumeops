"""Pulumi program to manage tail8d86e.ts.net tailnet configuration.

This program manages:
- ACL policy (grants, SSH rules, tag owners, tests)
- Device tags for infrastructure classification

Devices are tagged based on their role:
- tag:homelab - Server infrastructure (indri)
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
# Other services (grafana, kiwix, devpi, etc.) run in k8s with their own Tailscale devices.
indri = tailscale.get_device(name="indri.tail8d86e.ts.net")
indri_tags = tailscale.DeviceTags(
    "indri-tags",
    device_id=indri.node_id,
    tags=[
        "tag:homelab",  # Server role - allows SSH from workstations
        "tag:blumeops",  # Managed by this IaC
        # Service tags for services still hosted directly on indri
        "tag:forge",
        "tag:loki",
        "tag:registry",  # Zot container registry
        "tag:k8s-api",  # Kubernetes API server (minikube)
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

# ============== Exports ==============
pulumi.export("acl_id", acl.id)
pulumi.export("policy_hash", policy_hash)

pulumi.export("indri_device_id", indri.node_id)
pulumi.export("indri_tags", indri_tags.tags)

pulumi.export("sifaka_device_id", sifaka.node_id)
pulumi.export("sifaka_tags", sifaka_tags.tags)
