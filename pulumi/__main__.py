"""Pulumi program to manage tail8d86e.ts.net tailnet configuration."""

import pulumi
import pulumi_tailscale as tailscale
from pathlib import Path

# Read the HuJSON policy file
policy_path = Path(__file__).parent / "policy.hujson"
policy_content = policy_path.read_text()

# Manage the ACL - this completely overwrites the tailnet's ACL policy
acl = tailscale.Acl(
    "tailnet-acl",
    acl=policy_content,
)

# ============== Device Tags ==============
# Manage tags for devices in the tailnet

# indri - Mac Mini M1 running homelab services
indri = tailscale.get_device(name="indri.tail8d86e.ts.net")
indri_tags = tailscale.DeviceTags(
    "indri-tags",
    device_id=indri.node_id,
    tags=[
        "tag:homelab",
        "tag:grafana",
        "tag:forge",
        "tag:kiwix",
        "tag:devpi",
        "tag:loki",
        "tag:pg",
        "tag:feed",
        "tag:blumeops",
    ],
)

# Export useful info
pulumi.export("acl_id", acl.id)
pulumi.export("indri_device_id", indri.node_id)
pulumi.export("indri_tags", indri_tags.tags)
