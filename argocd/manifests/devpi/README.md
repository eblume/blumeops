# devpi PyPI Caching Proxy

devpi-server running in Kubernetes, providing:
- PyPI caching proxy at `root/pypi`
- Private package hosting at `eblume/dev`

## Setup

### 1. Create the root password secret

```fish
kubectl create namespace devpi
op inject -i argocd/manifests/devpi/secret-root.yaml.tpl | kubectl apply -f -
```

### 2. Deploy via ArgoCD

```fish
argocd app sync apps
argocd app sync devpi
```

The container will auto-initialize on first startup using the root password from the secret.

### 3. Create user and index (first time only)

After the pod is running:

```fish
# Login to devpi as root
uvx --from devpi-client devpi use https://pypi.tail8d86e.ts.net
uvx --from devpi-client devpi login root
# Enter root password when prompted

# Create eblume user (prompts for password - use the one from 1Password)
uvx --from devpi-client devpi user -c eblume email=blume.erich@gmail.com

# Create private index inheriting from PyPI
uvx --from devpi-client devpi index -c eblume/dev bases=root/pypi
```

## Usage

### As pip index (caching proxy)

Configure `~/.config/pip/pip.conf`:

```ini
[global]
index-url = https://pypi.tail8d86e.ts.net/root/pypi/+simple/
trusted-host = pypi.tail8d86e.ts.net
```

### Upload private packages

```fish
cd ~/code/personal/your-package
uv build
uv publish --publish-url https://pypi.tail8d86e.ts.net/eblume/dev/
```

## URLs

- Web UI: https://pypi.tail8d86e.ts.net
- PyPI cache: https://pypi.tail8d86e.ts.net/root/pypi/+simple/
- Private index: https://pypi.tail8d86e.ts.net/eblume/dev/+simple/

## Credentials

Stored in 1Password vault `blumeops`, item `kyhzfifryqnuk7jeyibmmjvxxm`:
- `root password` - devpi root user
- `password` - eblume user password
