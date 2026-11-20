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
- **noexec protects little.** It is, by inference (not shown; §3, item 1), a side
  effect of systemd's DynamicUser boundary, and `/tmp` is exec-capable
  regardless. Remove it once the control check under §3 ("Control check") shows a
  static-user workspace is exec-capable.
- **The real multi-client defect** is that all four builder instances run as
  one dynamic Unix user with one state tree. Per-repo state is not separate at
  the kernel level, and a PR job and a push-to-main job share a `/tmp`. Give each
  builder instance its own static user. That also removes noexec, if the control check under §3
  ("Control check") passes. PR B does not separate blumeops's own PR jobs from its privileged jobs:
  they stay on one instance (§1.1). Splitting them is a decision for Erich (§6).
- **Enumeration (§1.1) changes no verdict.** It shows which privileged jobs share
  the blumeops instance with fork PR jobs, and that sibling instances share the
  uid. Both reinforce §4.3 and §4.5; neither reverses them.
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
| Secrets in a PR job | Fork PRs: "the secrets are not available and the automatic token only has read permissions" ([Forgejo Actions reference](https://forgejo.org/docs/latest/user/actions/reference/), `pull_request` section, fetched this session; the secrets context is empty for a fork head). Bot PRs are fork PRs: the bot pushes to `talos/blumeops` and opens `talos:<branch>` against `eblume/blumeops` (blumeops `AGENTS.md`, Rule 2). In `build-container.yaml`'s `build-nix` job, `GITHUB_TOKEN` appears only in the PR-gated failure report (`:239-242`), and `BLUMEOPS_CI_OP_TOKEN` only in a step gated on `push` (`:253-255`). Hephaestus `build.yaml` uses `GITHUB_TOKEN` only in failure reports (`:171`, `:248`). | A fork PR job sees no repo secret and a read-only token. **Same-repo branch PRs are not covered:** the docs imply they get secrets and a write-capable token, and nothing here probes it (§7 probe 8). Whether the daemon's `EnvironmentFile` reaches job steps: unverified. |
| Other jobs' processes | Four daemons, capacity 1 each, run concurrently (`forge/runners.json:48-83`). Ringtail sets no `hidepid`. | A job can read `/proc` entries of same-uid processes. That includes the running job of every sibling instance, so a PR job on one repo's instance can read the environment and argv of a push or release job on another repo's instance while both run. Examples: `ZOT_PUSH_API_KEY` in the registry-push steps of horkos and talos `release.yaml` (`:145`, `:139`); the zot key in `skopeo`'s argv in blumeops `build-nix` (`:275`, `:291`). Unverified at runtime (§7 probes 1, 4, 10). |
| `/tmp` | `PrivateTmp` is implied as `disconnected` by DynamicUser (`systemd.exec(5)`, `man/systemd.exec.xml` ~`:755-760`). The private tmpfs gets `MS_NODEV\|MS_STRICTATIME` only (`src/core/namespace.c:824-838`, systemd v260.5). | Exec-capable and size-capped (`build-container.yaml:286-290` records ~3.2G). Private only because DynamicUser implies PrivateTmp; a static user needs it declared (§3, "Requirements of PR B"). |
| Workspace | `noexec` (see [§3](#3-the-noexec-mount)). | |

### What persists, and between whom

- **Per job:** the checkout and the job's own temporary files.
- **Per instance, across jobs:** the private `/tmp`, which lives as long as the
  unit. Hephaestus's reaper for "dirs that cancelled jobs leave behind"
  (`hephaestus/.forgejo/workflows/build.yaml:201-208`) is the observed symptom.
  Blumeops's single `nix-container-builder` instance for `blumeops` runs both
  PR jobs and push-to-main jobs (`build-container.yaml` triggers on both), so a
  PR job's leftovers reach the push job that holds the zot API key. This is
  the most concrete cross-trust-level channel found. The full list is in §1.1.
- **Per uid, across all instances:** `/var/lib/gitea-runner/*`, meaning every
  instance's `.runner` identity, `~/.cache/nix` (eval and fetcher caches), and
  workspaces.
- **Machine-wide:** `/nix/store` and the nix daemon, shared with root's own
  system builds.

### 1.1 Which jobs share an instance

Per the `labels` and `scope` fields, every builder-label job in blumeops runs on `ringtail-nix-builder-blumeops`.
That entry is repo-scoped (`forge/runners.json`, `scope: eblume/blumeops`), so
no other repo's instance takes blumeops jobs, per the `scope` field (enforcement not probed). Capacity is 1, so jobs on one
instance run one at a time, and the sharing there is sequential (`/tmp`,
workspace, `~/.cache/nix`, `.runner`). Instances of other repos run concurrently
under the same uid (§1, "Other jobs' processes"). The `runs-on` to instance
mapping comes from the `labels` and `scope` fields. forge-reconcile's handling of the
`nix-container-builder:host` label suffix was not read.

Every workflow with a job on the builder label, on blumeops `upstream/main`:

| Workflow (`runs-on` line) | Job(s) on the builder label | Trigger | Secrets the job can see |
|---|---|---|---|
| `build-container.yaml:149` | `build-nix` | `pull_request` (`containers/**`), `push` main, dispatch | PR run: `GITHUB_TOKEN` in the failure reporter only (`:239-242`). Push run: `BLUMEOPS_CI_OP_TOKEN` in the registry-push step (`:253-255`), which reads the zot key (`:261`). |
| `ringtail-flake-check.yaml:69` | `check` | `pull_request`, `push` main, dispatch | None on this job. `GITHUB_TOKEN` is on `fod-eval`, which runs on `indri-build`. |
| `provision-indri.yaml:93`, `:149` | `gate`, `preflight` | `push` main, dispatch | `FORGE_ACTIONS_RO_TOKEN` in `preflight` job env (`:151`). |
| `ringtail-rebuild.yaml:91`, `:147` | `gate`, `preflight` | `push` main, dispatch | `FORGE_ACTIONS_RO_TOKEN` in `preflight` job env (`:149`). |
| `unifi-apply.yaml:50`, `:96`, `:210` | `gate`, `preflight`, `report` | `push` main, dispatch | `FORGE_ACTIONS_RO_TOKEN` in `preflight` job env (`:98`). `BLUMEOPS_CI_OP_TOKEN` is on the `apply` job (`:183`), which runs on `indri-priv`, not the builder. |
| `ringtail-flake-update.yaml:43`, `:200`, `:420` | `update-and-build`, `checks-and-post`, `report-hard-failure` | `schedule` (Sun 05:00 UTC), dispatch | `update-and-build` blanks `GITHUB_TOKEN` from the `Update flake.lock` step (`:66`) on; checkout and snapshot keep it. `checks-and-post` takes `GITHUB_TOKEN` from secrets (`:219`, `:253`, `:364`); `report-hard-failure` (`:424`). |
| `auto-apply-digest.yaml:35` | `digest` | `schedule` (Sun 12:00 UTC), dispatch | `GITHUB_TOKEN` in job env (`:39`). |

**Who shares with whom.** Both PR-triggered builder jobs (`build-nix`, `check`)
run on the same instance, uid and `/tmp` as every privileged job in the table:
the zot push in `build-nix`, the `FORGE_ACTIONS_RO_TOKEN` preflights, and the
`GITHUB_TOKEN` writers in `ringtail-flake-update` and `auto-apply-digest`. Those
jobs are push-, schedule- or dispatch-triggered. A PR job can run right before one
and leave `/tmp` or workspace state for it. Hephaestus `build.yaml` (PR and push),
talos `ci.yaml` and `image-parts.yaml` (PR), and the horkos and talos `release.yaml`
push jobs (`ZOT_PUSH_API_KEY`) run on their own instances. None of them is on
blumeops's instance, but all of them share its uid (§1).

## 2. Shared state for several clients

| State | Shared today | Safe to share? | Scope it to |
|---|---|---|---|
| `/nix/store`, daemon | yes (all builders, root) | **Yes, for content.** An untrusted user cannot import paths, add substituters, or set trusted keys (defaults above, enforced by `invariants.nix:36-39`). For an input-addressed derivation, a path is the hash of the derivation, and the derivation contains its builder. The daemon checks fixed-output derivations against their declared hash (Nix semantics, not read from source here). The sandbox is on. Residual risk: disk fill, bounded by weekly GC at 14 days (`configuration.nix:1042-1046`). | Host-wide, as today |
| Nix eval and fetcher caches (`~/.cache/nix`) | yes, via the shared uid | **No.** A PR job can write an input-fetch cache entry that another repo's evaluation then reads. | Per repo, or per job |
| Runner identity (`.runner`, token env) | readable by the same uid (mode unverified) | **No** | Per instance |
| Private `/tmp` and workspace | per instance, across that instance's jobs (`/tmp` is private only with PrivateTmp, §3) | **No** across trust levels. Acceptable across jobs of one repo only if nothing privileged runs there. | Per job, or per trust level |
| Toolchains | not shared (rustup in `/tmp`, mise on indri) | **Yes, via the store** (§4.1) | Store path, per repo flake |
| Build target dirs | per instance `/tmp` | Cache by key, not by instance. Put them in per-job dirs. | Per job |

## 3. The noexec mount

**Verdict: incidental. Removed for the ringtail builder instances by PR B ([blumeops#2450](https://forge.ops.eblu.me/eblume/blumeops/pulls/2450)).** The probes [blumeops#2457](https://forge.ops.eblu.me/eblume/blumeops/pulls/2457) (run 18551, user nix-builder-blumeops) and [talos#719](https://forge.ops.eblu.me/eblume/talos/pulls/719) (run 5218, user nix-builder-talos) showed on two concurrent static builder instances: the workspace mounted `rw,nosuid,relatime` with no noexec, a copied ELF and a script both executed from it, and `/tmp` was private per instance. The horkos-runner `priv` control check is not recorded here.

1. **Origin.** Commit `ec3cc4e1ab30` (PR #1349) records run 5670 failing with
   exit 126 on `flake-lock-check`, with the workspace mounted
   `rw,nosuid,nodev,noexec` in the unit's namespace. No config sets it:
   `nixos/ringtail` has no mount option, and `noexec` appears only in comments.
   The mechanism is **inferred**: systemd's DynamicUser private boundary. For a dynamic user,
   systemd overmounts `/var/lib/private` with an empty tmpfs
   (`src/core/exec-invoke.c:3408-3421`), and that tmpfs is created with
   `MS_NOSUID|MS_NOEXEC|MS_NODEV` (`src/core/namespace.c:444-462`). The state
   directory lives under it. The commit's observed flags match. I did not trace
   bind-mount flag inheritance in source; the observation is from the commit.
2. **No stated purpose.** No doc, commit body, or config comment gives a goal.
   The only record is a symptom line (`docs/changelog/archive/v1.20.md:290`).
3. **It is bypassable, and its effect is limited.** It blocks direct exec from the workspace. `bash <script>` and `ld.so` bypass it, and `/tmp` is exec-capable
   (`namespace.c:824-838`), and a job can write and run anything within its uid.
4. **It has real cost.** Six `bash <script>` call sites
   (`.forgejo/workflows/ringtail-flake-update.yaml:110-143`, plus `:224`, `:374`,
   `:390`) and hephaestus's RAM-backed target and toolchain directories.

**Fix (PR B).** Builder instances stop using DynamicUser. Each gets a static
system user, the pattern `horkos-runner` already uses (`configuration.nix:868-931`).
If the §3 item 1 inference holds, no private boundary is created and so no noexec. The `bash` wrappers come out only after the control check under §3 "Control check" passes.
`invariants.nix:17-18` reads only the blumeops instance's `User`; the trust
assertion must iterate every builder instance once users differ.

**Requirements of PR B (not optional).** DynamicUser implies hardening that a
static user does not get. `horkos-runner` re-declares it by hand
(`configuration.nix:926-932`, commented "What DynamicUser=yes implied"). PR B
sets each builder instance to:

- `NoNewPrivileges = true`
- `ProtectSystem = "strict"`
- `ProtectHome = "read-only"`
- `PrivateTmp = true`
- `RemoveIPC = true`
- `RestrictSUIDSGID = true`

Without `PrivateTmp`, the "`/tmp` is private per instance" statements in §1 and
§2 are false, and the cross-job `/tmp` channel stays open. PR B's proof includes a
`/tmp` check across two instances, not only `id -u`.

**Control check (first step of PR B).** The horkos-runner unit is already static
(`DynamicUser = lib.mkForce false`, `configuration.nix:921`), and its
`WorkingDirectory` is `/var/lib/horkos-runner/priv` (`:925`), outside the
`/var/lib/private` tree where the inferred tmpfs sits. By the inference in §3, item 1 its
workspace should be exec-capable. **Unverified.** No blumeops doc or commit records
its mount flags (§7 probe 9). PR B runs `findmnt -T "$GITHUB_WORKSPACE" -o TARGET,FSTYPE,OPTIONS`
on the control and on a static builder instance before changing anything. The
control is a job on the `priv` label, so it is an approval-gated run that PR B's
author triggers.

**If noexec survives the static user.** Then the mount does not come from
DynamicUser, and the inference is wrong or incomplete. PR B records the mount source (`findmnt`
SOURCE and FSTYPE), fixes it at that source if blumeops config owns it, and keeps
the `bash` wrappers in `ringtail-flake-update.yaml` until a probe shows that
executing from the workspace works. Removing the wrappers (§6) is conditional on
that.

**Alternative rejected.** Keep DynamicUser and override the flags. The
`MS_NOEXEC` on the private boundary is hard-coded (`namespace.c:461`), and I found no
unit option that clears it.

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
  Keep fork-PR jobs secret-free (§1; same-repo PRs unverified, §7 probe 8), and
  keep privileged work on push-to-main, schedule, and Approve-and-run.
- Workflows held outside the client repo help only if the caller is also
  outside it. Not worth the cost now.

### 4.5 Toolchain-changing PRs

**Human-approved run for the bot's fork PRs. No two-step merge, no PR label gate.**

A toolchain-changing PR runs its own toolchain, as its code already does. The
approval is the review. For the bot's PRs, that approval is Forgejo's gate for
read-only authors: the run is held until a user with elevated permissions approves
([Forgejo: security of pull requests](https://forgejo.org/docs/latest/user/actions/security-pull-request/)).
The docs say a collaborator's same-repo PR is not held by that gate; that is unverified here (§7 probe 8).

A two-step merge is needed only if PR jobs pin to main, which §4.3 rejects. Hephaestus PR C is the first test of this path.

### 4.6 Can an untrusted job put something into the store, and can one repo affect another?

- An untrusted job can make the daemon realise any derivation it can express.
  The outputs enter the store as locally built paths.
- It cannot import paths, add substituters, or trust keys.
- For reproducible, input-addressed derivations, it cannot choose the content at a
  path another repo uses: the path is the derivation's hash, and the derivation
  includes its builder. Fixed-output derivations are hash-checked. Impure or
  non-reproducible builds are not covered by this argument (unverified).
- Residuals: **disk** (a PR can fill the store, bounded only by GC), **caches**
  per uid (§2), and **process state** across sibling instances (§1, probe 10). Flake `nixConfig` is ignored unless `accept-flake-config` is set
  (nix default; not set on ringtail; the default is unverified, see §7).

**Conclusion:** one repo's job can affect another's cache and disk. It cannot
change the store's content.

## 5. Conventions for client repos

1. **Declare CI tools in the repo's flake.** Use a `ci` dev shell, and run
   each workflow step as `nix develop .#ci -c …`. Nothing from `/tmp`, nothing
   downloaded per run.
2. **`mise.toml` is the only version pin.** The flake reads it. No second list.
3. **Repo secrets only on push to main, schedule, or a warrant-dispatched run.** A fork
   PR job gets a read-only `GITHUB_TOKEN` and no repo secret (Forgejo docs). Same-repo
   PR jobs are unverified (§7 probe 8).
4. **Do not rely on `/tmp` or the workspace surviving a job.** Put target and
   cache dirs under a per-job path. Keep reapers until the runner change lands.
5. **Privileged push jobs and PR jobs should not share a builder instance.**
   Blumeops's current single instance does, with the jobs listed in §1.1. Until
   per-job state exists, this is a known gap.
6. **Toolchain-changing PRs** go through Approve-and-run.

## 6. Sequence and hephaestus migration

- **PR A (this page):** analysis, cross-links from [[runners-and-trust]] and [[forgejo-runner]].
- **PR B (blumeops, after sign-off):** builder instances get static per-instance
  users, with the §3 hardening re-declared. The §3 control check runs first.
  `invariants.nix` checks each instance. The `bash` wrappers in
  `ringtail-flake-update.yaml` come out only if the control check shows exec works
  from the workspace. Proof: two concurrent instances report different `id -u`,
  a `/tmp` written by one is invisible to the other, and a `findmnt` of the
  workspace shows the result of the control check. Deploy is a merge to main (`ringtail-rebuild.yaml`
  is `class: auto`, `warrant-policy.yaml:100-101`), so PR B needs the
  auto-apply block (`mise run lint-auto-apply`). Status: merged; the two-instance probes above passed.
- **PR C (hephaestus, after B is live):** toolchain from the flake (rust-overlay
  reading `mise.toml`); remove rustup-into-`/tmp`, the `/tmp` target dir and its
  reaper; move the target dir to a per-job path on disk. The RAM constraint goes
  away once the target is on disk.

**Follow-ups, each a separate issue (not in these PRs):**
- Leftover `/tmp` state across jobs. On the talos builder, private `/tmp` held 98 entries, mostly `nix-develop-*` directories from earlier jobs. `PrivateTmp` scopes them to the unit, but they persist for the unit's lifetime, so one repo's jobs can see their own earlier leftovers. Clean per job or per repo.
- Per-job state for builder instances.
- Split builder instances by trust level (PR vs push-to-main). **Decision for Erich:** PR B alone does not separate blumeops's PR jobs from its privileged jobs (§1.1).
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
8. Same-repo branch PR: a `pull_request` job from a branch of `eblume/blumeops` (not a fork). Does its `secrets` context hold repo secrets, and is its `GITHUB_TOKEN` write-capable? Forgejo's docs imply yes; the bot cannot create this case (read-only on canonical), so a collaborator runs it. Names only.
9. The horkos-runner (`priv`) workspace mount: `findmnt -T "$GITHUB_WORKSPACE" -o TARGET,FSTYPE,OPTIONS`. Expect exec-capable (control check under §3). Repeat on a static builder instance after PR B.
10. Cross-instance read: a job on one builder instance reads `/proc/<pid>/environ` and `/proc/<pid>/cmdline` of the running job on a sibling instance. Names only. Expect success if `hidepid` is unset and the uid is shared; expect denial after PR B.
