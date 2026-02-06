---
title: use-pypi-proxy
tags:
  - how-to
  - python
---

# Use the PyPI Proxy

How to configure clients and publish packages to [[devpi]].

## Configure pip/uv

Point pip and uv at the proxy via environment variables:

```bash
export PIP_INDEX_URL="https://pypi.ops.eblu.me/root/pypi/+simple/"
export UV_INDEX_URL="https://pypi.ops.eblu.me/root/pypi/+simple/"
```

Unset both to fall back to public PyPI (e.g. when [[indri]] is offline).

The [dotfiles repo](https://github.com/eblume/dotfiles) has shell config
that manages this toggle.

## Upload Packages

```bash
# Build and publish with uv
cd ~/code/personal/your-package
uv build
uv publish --publish-url https://pypi.ops.eblu.me/eblume/dev/

# First time: uv will prompt for credentials
```

## Create Users/Indices

```bash
# Login as root
uvx devpi use https://pypi.ops.eblu.me
uvx devpi login root

# Create user (prompts for password - store in 1Password)
uvx devpi user -c USERNAME email=EMAIL

# Create index inheriting from PyPI mirror
uvx devpi index -c USERNAME/dev bases=root/pypi
```

## Verify Cache

```bash
# Check if devpi is caching
curl -s https://pypi.ops.eblu.me/+api | jq
```

## Related

- [[devpi]] - Service reference
