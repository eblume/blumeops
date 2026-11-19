---
title: "CI runner design: threat model and multi-client shape"
modified: 2026-11-19
last-reviewed: 2026-11-19
tags:
  - explanation
  - ai
  - design
  - security
---

# CI runner design: threat model and multi-client shape

Analysis for eblume/blumeops#2442. Scope: the `nix-container-builder` runners on
[[ringtail]] and the client repos that use them (blumeops, horkos, talos,
hephaestus). Every claim cites the file it comes from. Claims the config cannot
settle are marked **unverified** and listed with the probe that settles them in
[§7](#7-probes-for-unverified-claims). Companions: [[runners-and-trust]],
[[forgejo-runner]].

## Position

- **Adversary.** A PR author whose PR is attacker-controlled: a compromised
  talos agent is the main case. The PR controls its workflow file, its flake,
  its build scripts, proc macros, tests, and every dependency it adds. Which
  environment definition a job starts from does not change that: the PR's code
  runs in CI either way. Containment has to come from what a job can reach.
- **noexec protects nothing.** It is a side effect of systemd's DynamicUser
  boundary, and `/tmp` is exec-capable regardless. Remove it.
- **The real multi-client defect** is that all four builder instances run as
  one dynamic Unix user with one state tree. Per-repo state is not separate at
  the kernel level, and a PR job and a push-to-main job share a `/tmp`. Give each
  builder instance its own static user. That also removes noexec.
- **Toolchains come from the nix store**, declared by each repo's flake, with
  `mise.toml` staying the single declared version that nix reads. The store is
  a sound share surface. Homes, caches and `/tmp` are not.
- **PRs build with the PR's environment.** Pinning CI to main buys no
  containment on `pull_request`, so it is not adopted. Toolchain-changing PRs
  use the existing Approve-and-run gate.

## 1. Threat model

### What a builder job can reach

| Surface | Evidence | Consequence |
|---|---|---|
| Unix identity | The upstream module (nixpkgs `nixos-26.05` pin, rev `f1e5c356`) sets `DynamicUser = true` and `User = "gitea-runner"` for every instance (`nixos/modules/services/continuous-integration/gitea-actions-runner.nix:228-229`). Ringtail's builder instances set neither (`nixos/ringtail/configuration.nix:36-86`). | All four builder instances run as one uid. |
| State tree | `StateDirectory = "gitea-runner"` (module `:230`); `HOME` and `WorkingDirectory` are `/var/lib/gitea-runner/<instance>` (module `:219`, `:231`). | One state tree. Per-instance subdirectories are a naming convention, not a boundary. |
| Registration | The module loads `tokenFile` as `EnvironmentFile` (module `:280`). Ringtail's files are `root:root 0600` (`nixos/ringtail/secrets.json:51-88`, path from `configuration.nix:73-75`). | Systemd loads `EnvironmentFile` before the unit's privilege drop (systemd semantics, not read from source here). The daemon then holds it in its environment. |
| Host packages | Builder `hostPackages`: bash, coreutils, curl, gawk, gitMinimal, gnused, jq, nodejs, wget, nix, skopeo, `_1password-cli`, uv, python3 (`configuration.nix:43-45`). No mise. | Tools come from nixpkgs, not mise, on ringtail. |
| Network | The module's unit sets no network restriction (`PrivateNetwork`, `IPAddressDeny` absent, module `:200-290`). | A job reaches whatever the host reaches. Host firewall: unverified here. |
| Nix | Daemon `allowed-users` defaults to `*` (`nixos/modules/config/nix.nix:323`), `trusted-users` to `["root"]` (`:372`), `sandbox` to `true` (`:210`). Ringtail sets none of these. `nixos/ringtail/invariants.nix:36-39` fails evaluation if the builder user is trusted. | Builds run sandboxed, as an untrusted user. |
| Secrets in a PR job | `build-container.yaml` references `GITHUB_TOKEN` only in the failure report (`:242`). `BLUMEOPS_CI_OP_TOKEN` (`:255`) sits in a step gated on `push` to main. Hephaestus `build.yaml` uses `GITHUB_TOKEN` only in failure reports (`:171`, `:248`). | No secret on a PR's success path. Whether the daemon's `EnvironmentFile` reaches job steps: unverified. |
| Other jobs' processes | Builders run concurrently (four daemons, capacity 1 each, `forge/runners.json:48-83`). Ringtail sets no `hidepid`. | A job can read `/proc` entries of same-uid processes: other daemons, and another job's `skopeo` argv. Unverified at runtime. |
| `/tmp` | `PrivateTmp` is implied as `disconnected` by DynamicUser (`systemd.exec(5)`, `man/systemd.exec.xml` ~`:755-760`). The private tmpfs gets `MS_NODEV\|MS_STRICTATIME` only (`src/core/namespace.c:824-838`, systemd v260.5). | Exec-capable and size-capped (`build-container.yaml:286-290` records ~3.2G). |
| Workspace | `noexec` (see [§3](#3-the-noexec-mount)). | |

### What persists, and between whom

- **Per job:** the checkout and the job's own temporary files.
- **Per instance, across jobs:** the private `/tmp`, which lives as long as the
  unit. Hephaestus's reaper for "dirs that cancelled jobs leave behind"
  (`hephaestus/.forgejo/workflows/build.yaml:201-208`) is the observed symptom.
  Blumeops's single `nix-container-builder` instance for `blumeops` runs both
  PR jobs and push-to-main jobs (`build-container.yaml` triggers on both), so a
  PR job's leftovers reach the push job that holds the zot API key. This is
  the most concrete cross-trust-level channel found.
- **Per uid, across all instances:** `/var/lib/gitea-runner/*`, meaning every
  instance's `.runner` identity, `~/.cache/nix` (eval and fetcher caches), and
  workspaces.
- **Machine-wide:** `/nix/store` and the nix daemon, shared with root's own
  system builds.

## 2. Shared state for several clients

| State | Shared today | Safe to share? | Scope it to |
|---|---|---|---|
| `/nix/store`, daemon | yes (all builders, root) | **Yes, for content.** An untrusted user cannot import paths, add substituters, or set trusted keys (defaults above, enforced by `invariants.nix:36-39`). A path is the hash of its derivation, and a derivation contains its builder. The daemon checks fixed-output derivations against their declared hash (Nix semantics, not read from source here). The sandbox is on. Residual risk: disk fill, bounded by weekly GC at 14 days (`configuration.nix:1042-1046`). | Host-wide, as today |
| Nix eval and fetcher caches (`~/.cache/nix`) | yes, via the shared uid | **No.** A PR job can write an input-fetch cache entry that another repo's evaluation then reads. | Per repo, or per job |
| Runner identity (`.runner`, token env) | readable by the same uid (mode unverified) | **No** | Per instance |
| Private `/tmp` and workspace | per instance, across that instance's jobs | **No** across trust levels. Acceptable across jobs of one repo only if nothing privileged runs there. | Per job, or per trust level |
| Toolchains | not shared (rustup in `/tmp`, mise on indri) | **Yes, via the store** (§4.1) | Store path, per repo flake |
| Build target dirs | per instance `/tmp` | Cache by key, not by instance. Put them in per-job dirs. | Per job |

## 3. The noexec mount

**Verdict: incidental. Remove it.**

1. **Origin.** Commit `ec3cc4e1ab30` (PR #1349) records run 5670 failing with
   exit 126 on `flake-lock-check`, with the workspace mounted
   `rw,nosuid,nodev,noexec` in the unit's namespace. No config sets it:
   `nixos/ringtail` has no mount option, and `noexec` appears only in comments.
   The mechanism is systemd's DynamicUser private boundary. For a dynamic user,
   systemd overmounts `/var/lib/private` with an empty tmpfs
   (`src/core/exec-invoke.c:3408-3421`), and that tmpfs is created with
   `MS_NOSUID|MS_NOEXEC|MS_NODEV` (`src/core/namespace.c:444-462`). The state
   directory lives under it. The commit's observed flags match. I did not trace
   bind-mount flag inheritance in source; the observation is from the commit.
2. **No stated purpose.** No doc, commit body, or config comment gives a goal.
   The only record is a symptom line (`docs/changelog/archive/v1.20.md:290`).
3. **It blocks nothing an attacker needs.** `/tmp` is exec-capable
   (`namespace.c:824-838`), and a job can write and run anything within its uid.
4. **It has real cost.** Six `bash <script>` call sites
   (`.forgejo/workflows/ringtail-flake-update.yaml:110-143`, plus `:224`, `:374`,
   `:390`) and hephaestus's RAM-backed target and toolchain directories.

**Fix (PR B).** Builder instances stop using DynamicUser. Each gets a static
system user, the pattern `horkos-runner` already uses (`configuration.nix:868-931`).
No private boundary is created, so no noexec. Then remove the `bash` wrappers.
`invariants.nix:17-18` reads only the blumeops instance's `User`; the trust
assertion must iterate every builder instance once users differ.

**Alternative rejected.** Keep DynamicUser and override the flags. The
`MS_NOEXEC` on the private boundary is hard-coded (`namespace.c:461`), and no
unit option clears it.

## 4. The proposals

### 4.1 Each client defines its CI environment in nix

**Adopt, as the toolchain source (§5). Not a security boundary.**

The store is shared and safe for content (§2). A toolchain fetched once is
reused across runs and repos. The blumeops build path already works this way.

### 4.2 "mise for development, nix for CI"

**Adopt.** `mise.toml` stays the only place a version is declared, and the
flake reads it. Hephaestus's `build.yaml` already does this: its `nix eval` reads the
`mise.toml` `rust` pin (`.forgejo/workflows/build.yaml:210-211`). Hephaestus can
move the toolchain itself into the flake with `rust-overlay`. Two tools stay in step because they read one
file. Ringtail builders carry no mise, so mise is not a CI source there anyway.

### 4.3 PRs are built with main's environment definition

**Do not adopt for PR jobs now.**

- The PR's own code runs in CI with the same reach whatever the flake says:
  build scripts, proc macros, tests, the workflow file. Pinning changes only
  which tools wrap that code.
- On `pull_request` the workflow file comes from the PR (§4.4), so a PR can
  change the step that activates the pinned environment. Pinning is enforceable
  only if the activation lives outside the PR. No such arrangement exists for
  these runners.
- What pinning would buy is reproducibility and a clean post-merge job, and
  push-to-main jobs already run merged code.
- Cost: a second checkout and a two-step merge for toolchain changes (§4.5).

Revisit if a privileged job ever consumes a flake that came from a PR.

### 4.4 The workflow file comes from the PR

- Yes. `pull_request` runs the PR head's workflow, and its `runs-on` is free
  (`runners-and-trust.md`, "A PR's own workflow reaches every runner").
- `pull_request_target` runs the base-branch workflow with secrets, then the PR
  code runs in the same job. That is the known footgun. No blumeops workflow
  uses it (the matches are comments and one test fixture).
- **Recommendation:** do not adopt `pull_request_target` for these runners.
  Keep PR jobs secret-free (§1), and keep privileged work on push-to-main and
  Approve-and-run.
- Workflows held outside the client repo help only if the caller is also
  outside it. Not worth the cost now.

### 4.5 Toolchain-changing PRs

**Human-approved run. No two-step merge, no label.**

A toolchain-changing PR runs its own toolchain, as its code already does. The
approval is the review. A two-step merge is needed only if PR jobs pin to
main, which §4.3 rejects. Hephaestus PR C is the first test of this path.

### 4.6 Can an untrusted job put something into the store, and can one repo affect another?

- An untrusted job can make the daemon realise any derivation it can express.
  The outputs enter the store as locally built paths.
- It cannot import paths, add substituters, or trust keys.
- It cannot choose the content at a path another repo uses. The path is the
  derivation's hash, and the derivation includes its builder, so a different
  builder gives a different path. Fixed-output derivations are hash-checked.
- Residuals: **disk** (a PR can fill the store, bounded only by GC), and **caches**
  per uid (§2). Flake `nixConfig` is ignored unless `accept-flake-config` is set
  (nix default; not set on ringtail; the default is unverified, see §7).

**Conclusion:** one repo's job can affect another's cache and disk. It cannot
change the store's content.

## 5. Conventions for client repos

1. **Declare CI tools in the repo's flake.** Use a `ci` dev shell, and run
   each workflow step as `nix develop .#ci -c …`. Nothing from `/tmp`, nothing
   downloaded per run.
2. **`mise.toml` is the only version pin.** The flake reads it. No second list.
3. **Secrets only on push to main or a warrant-dispatched run.** A PR job holds
   the job `GITHUB_TOKEN` and nothing else.
4. **Do not rely on `/tmp` or the workspace surviving a job.** Put target and
   cache dirs under a per-job path. Keep reapers until the runner change lands.
5. **Privileged push jobs and PR jobs should not share a builder instance.**
   Blumeops's current single instance does. Until per-job state exists, this is
   a known gap.
6. **Toolchain-changing PRs** go through Approve-and-run.

## 6. Sequence and hephaestus migration

- **PR A (this page):** analysis, cross-links from [[runners-and-trust]] and [[forgejo-runner]].
- **PR B (blumeops, after sign-off):** builder instances get static per-instance
  users; `invariants.nix` checks each instance; remove the `bash` wrappers in
  `ringtail-flake-update.yaml`. Proof: a job runs a file from its workspace, a
  `findmnt` of the workspace shows no `noexec`, and two concurrent instances
  report different `id -u`. Deploy is a merge to main (`ringtail-rebuild.yaml`
  is `class: auto`, `warrant-policy.yaml:100-101`), so PR B needs the
  auto-apply block (`mise run lint-auto-apply`).
- **PR C (hephaestus, after B is live):** toolchain from the flake (rust-overlay
  reading `mise.toml`); remove rustup-into-`/tmp`, the `/tmp` target dir and its
  reaper; move the target dir to a per-job path on disk. The RAM constraint goes
  away once the target is on disk.

**Follow-ups, each a separate issue (not in these PRs):**
- Per-job state for builder instances.
- Split builder instances by trust level (PR vs push-to-main).
- `indri-build` is instance-scoped, so any repo's PR can target it
  (`forge/runners.json:39-47`).
- `priv` is reachable from a PR's own workflow (drill, blumeops#1749,
  `runners-and-trust.md`). The root-side apply enforces that the SHA is an
  ancestor of `origin/main` (`nixos/ringtail/ringtail-apply.sh:72-75`).

## 7. Probes for unverified claims

The source citations in §1 and §3 were read from the pinned nixpkgs and systemd sources in this session; the items below are what those sources cannot settle. None needs a secret value. Print names and counts only.

1. Two concurrent jobs on two builder instances: `id -u` in each. Expect the same uid.
2. A job's `$RUNNER_TEMP` and workspace: `findmnt -T "$GITHUB_WORKSPACE" -o TARGET,OPTIONS`. Expect `noexec`.
3. Does the job environment carry the daemon's `EnvironmentFile` variables? Names only: `env | cut -d= -f1 | grep -c -i token`.
4. Can a job read `/proc/<other-daemon-pid>/environ`? Expect no if hidepid is unset and same-uid applies.
5. Mode of `~/.../.runner` in another instance's directory.
6. Which LAN and tailnet hosts a job can reach (host firewall).
7. Nix's default for `accept-flake-config` (nix source).
