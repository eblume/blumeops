---
title: Mise Tasks
modified: 2026-08-31
last-reviewed: 2026-08-31
tags:
  - reference
  - tools
  - mise
---

# Mise Tasks

Operational tasks for BlumeOps, run via `mise run <task>`. Tasks live in
`mise-tasks/`; descriptions come from each script's `#MISE description=`
directive and argument parsing from `#USAGE` directives.

Run `mise tasks --sort name` for the live list with descriptions.

| Task | Description |
|------|-------------|
| `agent-authkey-sync` | Sync the Pulumi tag:agent Tailscale auth key into 1Password (for the agent-pod ExternalSecret) |
| `agent-health` | Fleet health via Grafana alert rules, using the agents-m2m JWT (agent-usable) |
| `agent-lint` | Run the CI lint gate (prek hookset) locally before pushing |
| `agent-metrics` | Run a PromQL query against Prometheus via Grafana, as the agents-m2m identity |
| `agent-repo-access` | [human] Reconcile the agents bot's forge collaborations, talos webhooks, and engagement labels against repos.json |
| `ai-sources` | Concatenate all BlumeOps source files for AI context |
| `branch-cleanup` | [human] Delete branches that have been merged into main (local and remote) |
| `changelog-check` | Validate changelog fragments are flat files in docs/changelog.d/ |
| `container-build-and-release` | [human] Trigger container build workflows via Forgejo API |
| `container-list` | List available containers and their recent tags |
| `container-version-check` | Validate container version consistency across nix derivations and service-versions.yaml |
| `dns-acme-cleanup` | [human] Delete orphaned ACME challenge TXT records in eblu.me |
| `dns-preview` | [human] Preview DNS changes to eblu.me with Pulumi |
| `dns-up` | [human] Apply DNS changes to eblu.me with Pulumi |
| `docs-check-frontmatter` | Check that all docs have required frontmatter fields |
| `docs-check-links` | Validate all wiki-links point to existing doc files |
| `docs-preview` | [human] Build docs with Dagger and serve locally, opening to a specific card |
| `docs-review` | Review the most stale documentation card by last-reviewed date |
| `docs-review-stale` | Report docs by git-last-modified date, highlighting stale ones |
| `docs-review-tags` | Print frontmatter tag inventory across all docs |
| `ensure-k3s-ringtail-kubectl-config` | [human] Ensure kubectl config for k3s-ringtail is set up on this workstation |
| `fly-deploy` | [human] Deploy the Fly.io public proxy |
| `fly-reload` | [human] Reload Fly.io proxy nginx config (re-resolves upstream DNS) |
| `fly-setup` | [human] One-time setup: configure Fly.io secrets and certs (idempotent) |
| `fly-shutoff` | [human] Emergency shutoff: stop all Fly.io proxy machines |
| `forge-api` | Authenticated Forgejo API call against forge.ops.eblu.me (api-token from the blumeops vault) |
| `frigate-export-model` | [human] Export YOLOv9 model weights to ONNX for Frigate NVR via Dagger |
| `horkos-test` | Run the horkos client-tooling unit tests — request-run and verify-runs (no network, no cluster) |
| `mirror-create` | [human] Create a new upstream mirror in the mirrors/ Forgejo org |
| `mirror-update-pats` | [human] Push the current GitHub PAT onto every forge pull mirror on indri |
| `ollama-down` | [human] Scale the ollama inference service down (replicas 1 -> 0) to free the RTX 4080 |
| `ollama-up` | [human] Scale the ollama inference service up (replicas 0 -> 1) for an evaluation window |
| `op-backup` | [human] Encrypt a 1Password .1pux export and send to indri for borgmatic |
| `pending-deploys` | Report first-party image releases not yet pinned/deployed on main, plus open pin-bump PRs |
| `pr-comments` | Read all comments, reviews and review threads on a PR |
| `provision-indri` | [human] Run ansible playbook to provision indri |
| `provision-ringtail` | [human] Run ansible playbook to provision ringtail (NixOS) |
| `provision-sifaka` | [human] Run ansible playbook to provision sifaka |
| `prune-ringtail-generations` | [human] Prune old NixOS generations on ringtail, preserving rollback safety |
| `request-run` | Request a privileged workflow run (approval-gated; see warrant-approval-gated-runs) |
| `review-compliance-reports` | Summarize the latest Prowler security-scan reports from sifaka |
| `runner-logs` | List recent Forgejo Actions runs or fetch logs for a specific job |
| `service-review` | Review the most stale service for version freshness |
| `services-check` | [human] Check that all services are online and responding |
| `spork-create` | [human] Create a spork (floating-branch soft-fork) of a mirrored upstream project |
| `tailnet-preview` | [human] Preview tailnet changes with Pulumi |
| `tailnet-up` | [human] Apply tailnet changes with Pulumi |
| `verify-runs` | Sweep open Approve tasks: match to workflow runs, close settled ones (warrant Phase 2 audit) |
| `warrant-bot-drift` | [human] Assert warrant-bot still holds exactly write on blumeops and nothing more (read-only) |
| `warrant-bot-provision` | [human] Provision the warrant-bot forge identity + dispatch PAT (gilbert, human-run) |

## Related

- [[dagger]] — CI/CD build engine (containers, docs)
- [[ansible]] — Configuration management
- [[argocd-cli]] — ArgoCD deployment workflows
- [[pulumi]] — DNS and Tailscale IaC
- [[qart-tuner]] — QR code art generator (`utils/qart/`)
