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

# Export useful info
pulumi.export("acl_id", acl.id)
