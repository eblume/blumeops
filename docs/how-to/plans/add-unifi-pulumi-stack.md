---
title: "Plan: Add UniFi Pulumi Stack"
modified: 2026-02-14
tags:
  - how-to
  - plans
  - networking
  - pulumi
---

# Plan: Add UniFi Pulumi Stack

> **Status:** Abandoned
> **Superseded by:** [[segment-home-network]]

## Why Abandoned

Attempted Feb 2026 with the `ubiquiti-community/unifi` Terraform provider via `pulumi package add`. Two issues made the approach unviable:

1. **API key auth skips UniFi OS auto-detection** ([provider bug #74](https://github.com/ubiquiti-community/terraform-provider-unifi/issues/74)) — requires username/password instead, which is unsuitable for IaC
2. **"No-op" update on the default LAN network reset undeclared properties** — bricked the network, requiring a factory reset and backup restore

The provider ecosystem (ubiquiti-community, filipowm, pulumiverse) is too immature for critical single-device infrastructure like the home router. A provider bug that causes a network outage on a no-op update is an unacceptable risk.

## What Survives

The network segmentation goals from this plan remain valid and are carried forward in [[segment-home-network]], which describes how to configure three-network segmentation manually through the UX7 web UI.

## Related

- [[segment-home-network]] — Manual segmentation plan (replacement)
- [[unifi]] — Reference card
