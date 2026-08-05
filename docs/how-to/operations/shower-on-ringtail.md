---
title: Shower App on Ringtail
modified: 2026-05-10
last-reviewed: 2026-05-10
tags:
  - how-to
  - operations
  - kubernetes
  - django
---

# Shower App on Ringtail

How the Adelaide / Heidi / Addie baby shower app is deployed. The app is a
Django project ([`adelaide-baby-shower-app`](https://forge.eblu.me/eblume/adelaide-baby-shower-app))
released as a wheel to the Forgejo Packages PyPI index and run on
[[ringtail]]'s k3s cluster. Public landing page at `shower.eblu.me`, staff
console + admin UI at `shower.ops.eblu.me` (tailnet only).

The contract this deploy implements is defined in the app repo's
`docs/how-to/hosting.md` — read that for the env-var contract, security
model, and storage requirements before changing anything here.

## Routing

```
Internet → shower.eblu.me
            │ (Fly.io nginx — public)
            ▼
        Caddy on indri (shower.ops.eblu.me)
            │
            ▼
        Tailscale ProxyGroup ingress (shower.tail8d86e.ts.net)
            │
            ▼
        Service shower:8000 → Pod (Django + gunicorn)
```

| Hostname | Reachable from | Notes |
|---|---|---|
| `shower.eblu.me` | Public internet | Guest surface only — splash, `/prizes/<token>/`, `/static/`, `/media/`. Everything authenticated 403s with a tailnet pointer. |
| `shower.ops.eblu.me` | Tailnet | Full app surface — `/host/`, `/admin/`, the works |
| `shower.tail8d86e.ts.net` | Tailnet | Bare ProxyGroup endpoint Caddy proxies to |

## Defense layers (public side)

The public surface is guest-only, so the threat model collapses: there
is no credential-accepting endpoint reachable from WAN, and nothing on
WAN that requires authentication.

1. **edge auth lockout** — fly nginx 403s `/admin/`, `/host/`, and
   anything that would redirect into them. Anyone hitting an auth URL
   on WAN gets a "tailnet only" message.
2. **fly nginx `limit_req zone=general`** — 10 r/s per Fly-Client-IP
   cushion for the splash form.
3. **django-axes** — 5 fails / 1 hour lockout per `(username, ip_address)`,
   running on the tailnet-side login. Provides the only credential
   defense, since brute-force is only reachable to tailnet members.

The QR codes that `/host/` (on tailnet) generates for guests embed
`https://shower.eblu.me/...` even though the QR view is served from
the tailnet host. The app's `PUBLIC_URL_BASE` setting (added in v1.0.1)
overrides Django's `request.build_absolute_uri()` for those URLs.

## Persistent storage

| Mount | PVC | Type | Why |
|---|---|---|---|
| `/app/media` | `shower-media` | NFS RWX on sifaka (`/volume1/shower`) | Prize photos survive pod rescheduling |
| `/app/data` | `shower-data` | k3s `local-path` RWO | SQLite DB; NFS file locking can't be trusted for WAL/journal |

The container has the app + its Python deps baked in at nix build time
(`buildPythonPackage` against the wheel fetched from forge PyPI). The
entrypoint runs migrations, runs `collectstatic`, and `exec`s gunicorn —
no pip-at-boot. A `local_settings.py` shim overrides `DATABASES.NAME`,
`MEDIA_ROOT`, and `STATIC_ROOT` to absolute paths under `/app/`,
sidestepping the wheel's `BASE_DIR = parent.parent` of an
in-site-packages settings module.

## Backups

[[borgmatic]] (running on indri) captures both halves of the persistent
state on its daily 2 a.m. run:

- **`/app/data/db.sqlite3`** — dumped via `kubectl exec`'s
  `sqlite3.backup()` against the live pod (entry in
  `borgmatic_k8s_sqlite_dumps`, context `k3s-ringtail`). The dumped
  file lands in `borgmatic_k8s_dump_dir` on indri and is picked up by
  the main source-directory sweep.
- **`/app/media`** — picked up via `/Volumes/shower`, the SMB mount of
  `sifaka:/volume1/shower` on indri. The same Synology share is exposed
  via SMB *and* NFS simultaneously; ringtail's pod uses the NFS export,
  while indri reads the SMB side for the borgmatic source.

Both archive to [[sifaka]] (`borg-backups`) and BorgBase offsite, with
retention `keep_daily=7 / keep_monthly=12 / keep_yearly=1000`.

The SMB mount on indri is set up manually once via Finder (Cmd-K →
`smb://sifaka/shower`, save credentials, "Always log in" so it
reconnects after reboot). If `/Volumes/shower` is missing at backup
time borgmatic will fail loudly — `source_directories_must_exist: true`
applies to all entries.

## One-time setup steps

These steps are required the first time the service is deployed and are
not encoded in the manifests.

### 1. NFS + SMB share on sifaka

On the Synology DSM web UI:

1. **Control Panel → Shared Folder → Create**. Name: `shower`,
   Location: Volume 1. Leave the rest at default.
2. **Control Panel → File Services → NFS → NFS Rules** (on the
   `shower` row's *Permissions* tab). Add a rule mirroring the other
   shares' pattern: Hostname/IP=`192.168.1.0/24` and again for
   `100.64.0.0/10`, Privilege=Read/Write, Squash=`Map all users to
   admin` (= `all_squash`), and tick *Allow connections from
   non-privileged ports*. (See [[sifaka#NFS Exports]] — the existing
   `frigate`, `paperless`, etc. shares use this exact pattern.)
3. **Control Panel → File Services → SMB**: leave SMB enabled
   globally. No per-share rule required — the share inherits the
   default `eblume` access.
4. The directory ownership at `/volume1/shower` will end up
   `root:root`, mode `0777` (DSM default) — which is fine because
   `all_squash` rewrites every NFS write to `admin:users`, and the
   `0777` lets pods read what other pods wrote. No `chown` needed.

After the share exists, mount it on indri for borgmatic:

- In Finder, **Cmd-K → `smb://sifaka/shower`**, sign in as `eblume`,
  and tick **Remember in Keychain** + **Always log in** so it
  reconnects on reboot. This produces `/Volumes/shower`, which the
  borgmatic source-directory list points at.

### 2. 1Password item

Item name: **`Shower (blumeops)`** in the `blumeops` vault.
Required property:

| Field | Value |
|---|---|
| `secret-key` | Output of `openssl rand -base64 48` |

The `ExternalSecret` `shower-app-secrets` will sync this into the
`shower` namespace as a `Secret` and `envFrom` exposes it as
`DJANGO_SECRET_KEY` to the container.

**Never reuse a key that has ever been in git history.** Per the app's
hosting.md, an early dev key was committed before being replaced with
the `django-insecure-...` placeholder; the production key must be
freshly generated.

### 3. Container image

Built by the `build-container` Forgejo Actions workflow on the
`nix-container-builder` runner (ringtail, amd64). The wheel is fetched
from forge PyPI at nix build time and baked into the image — no
pip-at-runtime. To bump the version, change `version` in
`containers/shower/default.nix` and update `wheelHash` (or set it to
`pkgs.lib.fakeHash` and let the next build print the correct one).

Trigger with:

```fish
mise run container-build-and-release shower
```

After the workflow finishes, update `images[].newTag` in
`argocd/manifests/shower/kustomization.yaml` to the resulting
`vX.Y.Z-<sha>-nix` tag, then commit.

### 4. DNS

`pulumi/gandi/__main__.py` declares the `shower-public` CNAME pointing
at `blumeops-proxy.fly.dev.`. Apply with:

```fish
mise run dns-preview
mise run dns-up
```

### 5. Fly.io certificate

```fish
fly certs add shower.eblu.me -a blumeops-proxy
```

(Add to `mise-tasks/fly-setup` so re-runs of the one-time setup pick
it up.)

### 6. Caddy on indri

`shower` is in `ansible/roles/caddy/defaults/main.yml`. Push with:

```fish
mise run provision-indri -- --tags caddy
```

### 7. Create the admin user

The container's entrypoint runs `migrate --noinput` + `collectstatic
--noinput --clear` before gunicorn, so a fresh `db.sqlite3` is schema-
ready as soon as the pod boots. It does *not* create a Django superuser
— that has to happen once, interactively, after the first pod is up:

```fish
kubectl --context=k3s-ringtail -n shower exec -it deploy/shower -- \
    python -m django createsuperuser
```

Use `erich` / your usual email. The same account doubles as the
`@staff_member_required` login for `/host/`. Subsequent staff accounts
can be created from `/admin/auth/user/` once you're signed in.

## Deploying a new version

1. Bump the wheel version in the app repo (`adelaide-baby-shower-app`)
   and release it to Forgejo PyPI.
2. Bump `appVersion` in `containers/shower/default.nix` to match.
3. `mise run container-build-and-release shower`. Verify the build
   with `mise run runner-logs`.
4. Update the `newTag` in `argocd/manifests/shower/kustomization.yaml`
   to the new `[main]` SHA tag.
5. Commit (C0 after PR merge — see [[build-container-image#Squash-merge and container tags]]).
6. `argocd app sync shower`.

## Verifying after a deploy

```fish
kubectl --context=k3s-ringtail -n shower get pods
kubectl --context=k3s-ringtail -n shower logs deploy/shower
curl -sf https://shower.ops.eblu.me/  # tailnet
curl -sf https://shower.eblu.me/      # public
curl -I https://shower.eblu.me/admin/users/  # expect 403 (edge block)
curl -I https://shower.ops.eblu.me/admin/    # expect 200 / 302 (login)
```

## Related

- [[expose-service-publicly]] — Fly.io proxy + Tailscale pattern
- [[deploy-k8s-service]] — generic ArgoCD service onboarding
- [[ringtail]] — the cluster
- [`hosting.md`](https://forge.eblu.me/eblume/adelaide-baby-shower-app/src/branch/main/docs/how-to/hosting.md) — app's deployment contract
