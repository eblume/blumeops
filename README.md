# blumeops
aka "Blue Mops"

Tools and configuration for Erich Blume's personal infrastructure, orchestrated
across a Tailscale tailnet.

This is a homelab, but it's also a testing ground for AI-assisted
infrastructure development. Much of this codebase was co-authored with [Claude
Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview),
and the repo places heavy emphasis on documentation, process, and change
classification to make that collaboration work well. I don't know entirely how
I feel about LLMs in our current era (there are real concerns about how
training data is sourced and energy subsidy) but it felt important to learn how
to work with these tools.

The full documentation is published at **[docs.eblu.me](https://docs.eblu.me)**
and lives in the [`docs/`](docs/) directory, structured around the
[Diataxis](https://diataxis.fr/) framework and designed to be compatible with
[Obsidian](https://obsidian,nd)/[Obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim).

## What runs here

Services are a mix of Kubernetes pods (managed by ArgoCD), macOS LaunchAgent
services (managed by Ansible), and NixOS systemd services (managed by Nix
flakes), all connected via Tailscale:

- **Indri** (Mac Mini M1) - primary server. Most services run in Minikube via
  ArgoCD; Forgejo, Caddy, and others run natively as LaunchAgent services via
  Ansible.
- **Ringtail** (NixOS desktop, RTX 4080) - GPU workloads (Frigate NVR,
  Authentik SSO) on k3s, plus NixOS systemd services.
- **Sifaka** (Synology NAS) - backup target and bulk storage.

Notable services include Grafana/Prometheus/Loki observability, Immich photos,
Jellyfin media, Forgejo git forge, a Zot container registry, and more. Public
access is routed through a Fly.io proxy; everything else is tailnet-only.

## Project structure

```
ansible/            Ansible playbooks and roles (indri, sifaka)
argocd/apps/        ArgoCD Application definitions
argocd/manifests/   Kubernetes manifests per service
containers/         Custom container builds (Dockerfile + Nix)
docs/               Diataxis documentation (published at docs.eblu.me)
fly/                Fly.io public proxy configuration
mise-tasks/         Operational scripts run via mise
nixos/              NixOS configuration for ringtail
pulumi/             Pulumi IaC (Tailscale ACLs, Gandi DNS)
.dagger/            Dagger CI pipelines
.forgejo/           Forgejo Actions CI/CD workflows
```

## Getting started

You'll need [Homebrew](https://brew.sh) and [mise](https://mise.jdx.dev):

```bash
brew bundle                    # install CLI tools (argocd, tea, flyctl, etc.)
mise install                   # install managed toolchains (ansible, pulumi, dagger, etc.)
uvx pre-commit install         # set up pre-commit hooks
```

Pre-commit hooks enforce secret scanning (TruffleHog), linting, formatting, and
custom checks like doc link validation and the Mikado branch invariant. Run
them manually with `uvx pre-commit run --all-files`.

Operational tasks are driven through mise. Run `mise tasks` to see what's
available. Key examples:

```bash
mise run provision-indri       # deploy to indri via Ansible
mise run services-check        # verify service health
mise run container-list        # list tracked container images
```

## AI-assisted development

This repo is designed to be worked on by both humans and AI agents. The
[`CLAUDE.md`](CLAUDE.md) file provides instructions for Claude Code, and the
[`docs/tutorials/ai-assistance-guide.md`](docs/tutorials/ai-assistance-guide.md)
explains the full workflow.

Changes are classified before starting work:

- **C0** - quick fixes, committed directly to main
- **C1** - feature branch + PR, documentation written before code
- **C2** - multi-phase work using the Mikado method for dependency tracking

See the [agent change process](docs/how-to/agent-change-process.md) for
details.

## License

[GPLv3](LICENSE)
