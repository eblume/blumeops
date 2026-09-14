---
title: Create Release Artifact Workflow
modified: 2026-09-14
last-reviewed: 2026-09-14
tags:
  - how-to
  - forgejo
  - ci
---

# Create a Release Artifact Workflow

How to set up a Forgejo Actions workflow that builds an artifact and publishes it to Forgejo generic packages. Uses the CV repo (`forge.ops.eblu.me/eblume/cv`) workflow as the reference implementation.

> **Deprecated:** this `FORGE_TOKEN` generic-package publish pattern is retired. The cv package now goes through the horkos publisher → zot (see eblume/horkos#17); this doc is kept for the historical shape.

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

Create `.forgejo/workflows/<name>-release.yaml` with `workflow_dispatch` and a version input. Use the semver bump pattern (see `cv-release.yaml` for the full upload flow, or `build-blumeops.yaml` for the version bump logic only — it uploads to Forgejo releases, not generic packages).

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
      "https://forge.eblu.me/api/packages/eblume/generic/<package>/${VERSION}/${TARBALL}"
```

## 3. Link the package to the repo

After the first successful upload, the package appears under your **user-level** packages at `https://forge.eblu.me/eblume/-/packages` but is not yet linked to the repo.

To link it:

1. Go to `https://forge.eblu.me/eblume/-/packages`
2. Click the package name
3. Click **Settings**
4. Under **Link this package to a repository**, select the repo
5. Click **Save**

Once linked, the package shows up in the repo's **Packages** tab and the repo links back to the package.

## 4. Create a deploy workflow (optional)

If the artifact is consumed by a k8s deployment, create a separate deploy workflow in blumeops. This keeps the build/release concern in the source repo and the deploy concern in blumeops (for the retired version of this pattern, see `cv-deploy.yaml` in git history; the current flow goes through the horkos publisher → zot, eblume/horkos#17).

## Pushing a commit back to a protected `main`

Some release flows commit back to `main` (e.g. `build-blumeops.yaml` bumps
`docs_version` + builds the changelog; the horkos publisher's PR bumps the `cv_version` pin — see eblume/horkos#17).
`main` on blumeops is branch-protected with a push whitelist limited to
`eblume`, and **the automatic Forgejo Actions token cannot be push-whitelisted**
(Forgejo [#11159](https://codeberg.org/forgejo/forgejo/issues/11159)) — so a
plain `git push origin HEAD:main` is rejected with `pre-receive hook declined`.

The fix is to authenticate the push as a whitelisted user via a PAT, not the
automatic token. The PAT is no longer an Actions secret: per-purpose CI
secrets were retired in favor of job-time `op read` of the `blumeops-ci`
vault ([[blumeops-ci-item-migration]]), so `build-blumeops.yaml` reads the
`eblume`-owned main-push PAT (item `blumeops-ci/forge-main-push/token`,
scope `write:repository`) at push time with the `BLUMEOPS_CI_OP_TOKEN`
service account, and pushes with it directly — checkout runs with
`persist-credentials: false`, so no credential sits in the worktree:

```yaml
- name: Commit release changes
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.BLUMEOPS_CI_OP_TOKEN }}
  run: |
    MAIN_PUSH_TOKEN=$(op read 'op://blumeops-ci/forge-main-push/token')
    echo "::add-mask::$MAIN_PUSH_TOKEN"
    git -c credential.helper= push \
      "https://eblume:${MAIN_PUSH_TOKEN}@forge.eblu.me/eblume/blumeops.git" \
      HEAD:main
```

The push then authenticates as `eblume` and passes branch protection. The
release-creation API call can keep using the automatic `GITHUB_TOKEN`
(API actions aren't gated by the push whitelist); only the git push needs
the PAT.

> The commit author can stay `Forgejo Actions` — branch protection checks the
> **pusher** (the PAT owner), not the commit author.

## Related

- [[deploy-k8s-service]] - Deploying the service that consumes the artifact
- [[add-ansible-role]] - Adding Ansible roles
- [[agents-forgejo-bot]] - the bot identity and the `main` branch-protection model
- [[blumeops-ci-item-migration]] - the per-purpose CI secrets that moved to job-time `op read`
