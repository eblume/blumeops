---
title: Kingfisher
modified: 2026-03-28
last-reviewed: 2026-03-28
tags:
  - service
  - security
---

# Kingfisher

Secret detection and live validation scanner for Forgejo repositories, using MongoDB's open-source [Kingfisher](https://github.com/mongodb/kingfisher) tool.

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `kingfisher` |
| **Image** | `ghcr.io/mongodb/kingfisher` (see `argocd/manifests/kingfisher/kustomization.yaml` for current tag) |
| **Schedule** | Sunday 4am (after Prowler k8s scan at 3am) |
| **Reports** | `sifaka:/volume1/reports/kingfisher/` (NFS) |
| **Manifests** | `argocd/manifests/kingfisher/` |
| **Upstream** | `forge.eblu.me/mirrors/kingfisher` (GitHub mirror) |

## What it does

Runs as a weekly CronJob that scans all repositories in the `eblume` user on Forgejo for leaked secrets, API keys, and credentials. Produces timestamped HTML and JSON reports on the sifaka NFS share.

Uses the Forgejo/Gitea API to enumerate repos, then clones and scans each one. Validation is enabled (secrets are tested against their respective APIs to confirm they're live). Reports are HTML only.

## Pre-commit hook

Kingfisher also runs as a prek hook alongside TruffleHog for comparative secret detection coverage. The hook uses `--staged` mode (only checks staged files) with validation disabled for fast, offline-safe commits.

## Known false positives

- **Postgres URL with `op://` template** — 1Password External Secrets template references match the postgres connection string pattern. Not a real credential.
- **GitHub legacy secret key in `.git/`** — git commit SHAs are 40-char hex strings matching the old GitHub PAT format. Only appears in full-repo scans, not `--staged` mode.

## Ad-hoc scan

```fish
kubectl create job --from=cronjob/kingfisher kingfisher-manual -n kingfisher --context=minikube-indri
kubectl logs -f job/kingfisher-manual -n kingfisher --context=minikube-indri
```

## Limitations

- Clone URLs come from Forgejo's API response using the instance's public `ROOT_URL` (`forge.eblu.me`), so clones roundtrip through Fly.io. Mirror/org scanning is excluded for now to avoid unnecessary external bandwidth. A clone URL rewrite option would need an upstream contribution.
- Only one output format per invocation. Currently producing HTML only.

## See also

- [[prowler]] — CIS Kubernetes, image, and IaC compliance scanning
- [[read-compliance-reports]] — how to access and interpret reports
