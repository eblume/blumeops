---
title: Create Release Artifact Workflow
modified: 2026-02-12
tags:
  - how-to
  - forgejo
  - ci
---

# Create a Release Artifact Workflow

How to set up a Forgejo Actions workflow that builds an artifact and publishes it to Forgejo generic packages. Uses the CV repo (`forge.ops.eblu.me/eblume/cv`) workflow as the reference implementation.

## Prerequisites

- A Forgejo repo with a build pipeline (Dagger, script, etc.)
- The `FORGE_TOKEN` secret provisioned via the `forgejo_actions_secrets` Ansible role

## 1. Add the repo to Ansible secrets

In `ansible/roles/forgejo_actions_secrets/defaults/main.yml`, add an entry under `forgejo_actions_secrets_repos`:

```yaml
forgejo_actions_secrets_repos:
  - repo: my-repo
    secrets:
      - name: FORGE_TOKEN
        value_var: forgejo_api_token
```

Then provision: `mise run provision-indri -- --tags forgejo_actions_secrets`

This is required because Forgejo's built-in `GITHUB_TOKEN` does not have permissions for the packages API.

## 2. Create the workflow

Create `.forgejo/workflows/<name>-release.yaml` with `workflow_dispatch` and a version input. Use the semver bump pattern (see `cv-release.yaml` or `build-blumeops.yaml` for examples).

The upload step uses `FORGE_TOKEN`:

```yaml
- name: Upload to Forgejo packages
  env:
    FORGE_TOKEN: ${{ secrets.FORGE_TOKEN }}
  run: |
    curl -fsSL \
      -X PUT \
      -H "Authorization: token $FORGE_TOKEN" \
      --upload-file "./$TARBALL" \
      "https://forge.ops.eblu.me/api/packages/eblume/generic/<package>/${VERSION}/${TARBALL}"
```

## 3. Link the package to the repo

After the first successful upload, the package appears under your **user-level** packages at `https://forge.ops.eblu.me/eblume/-/packages` but is not yet linked to the repo.

To link it:

1. Go to `https://forge.ops.eblu.me/eblume/-/packages`
2. Click the package name
3. Click **Settings**
4. Under **Link this package to a repository**, select the repo
5. Click **Save**

Once linked, the package shows up in the repo's **Packages** tab and the repo links back to the package.

## 4. Create a deploy workflow (optional)

If the artifact is consumed by a k8s deployment, create a separate deploy workflow in blumeops (see `cv-deploy.yaml`). This keeps the build/release concern in the source repo and the deploy concern in blumeops.

## Related

- [[deploy-k8s-service]] - Deploying the service that consumes the artifact
- [[add-ansible-role]] - Adding Ansible roles
