{ config, lib, pkgs, hephPkg, ... }:
let
  mcquackLogrotate = pkgs.writeScript "mcquack-logrotate" (builtins.readFile ./mcquack-logrotate.sh);
  # The heph hub (eblume/blumeops#1655): the store hephd the generation's
  # mcquack.eblume.heph agent runs. Paths are the role's current values
  # (ansible/roles/heph/defaults/main.yml) - the db, socket, PWA checkout
  # and log paths all stay put.
  hephDataDir = "/Users/erichblume/.local/share/heph";
  hephPwaRoot = "/Users/erichblume/.cache/heph-pwa-src/heph-pwa";
  # The ringtail agent spoke's dedicated OIDC sub (talos-heph identity). It
  # arrives in argv: hephd accepts --authorized-sub argv-only, so the wrapper
  # below cats the seeded file at startup instead of the store carrying it.
  hephHubSubFile = "/Users/erichblume/.config/heph-hub/authorized-sub";
  hephHubRunner = pkgs.writeShellScriptBin "mcquack-heph-hub" ''
    sub_file=${hephHubSubFile}
    if [ ! -r "$sub_file" ] || [ ! -s "$sub_file" ]; then
      printf 'error: heph authorized-sub file missing or empty at %s; seed it with `mise run seed-secrets indri`\n' "$sub_file" >&2
      exit 1
    fi
    exec ${hephPkg}/bin/hephd \
      --mode server \
      --http-addr 0.0.0.0:8787 \
      --db ${hephDataDir}/heph.db \
      --socket ${hephDataDir}/hephd.sock \
      --web-root ${hephPwaRoot} \
      --oidc-issuer https://authentik.ops.eblu.me/application/o/heph/ \
      --oidc-audience heph \
      --authorized-sub "$(cat "$sub_file")"
  '';
  # Removes the old cargo-installed heph bins from ~/.cargo/bin so a shell with
  # it on PATH can't shadow the store bins; a no-op once they are gone.
  hephCargoBinCleanup = pkgs.writeShellScriptBin "mcquack-heph-cargo-bin-cleanup" ''
    set -euo pipefail
    dir=/Users/erichblume/.cargo/bin
    [ -d "$dir" ] && [ ! -L "$dir" ] || exit 0
    for b in heph hephd heph-tui heph-quickadd; do
      ${pkgs.coreutils}/bin/rm -rf -- "$dir/$b"
    done
  '';
  # The four *-metrics collectors feeding alloy's node_exporter textfile dir (PR 4 moved them here).
  mcquackBorgmaticMetrics = pkgs.writeScript "mcquack-borgmatic-metrics" (builtins.readFile ./mcquack-borgmatic-metrics.sh);
  # forge/runners.json is the declared source for the runner fleet
  # (eblume/blumeops#1526). The read is relative to this flake root — it
  # holds only while the file is git-tracked at the repo root and the apply
  # runs from a checkout (/etc/blumeops, CI checkouts).
  forgejoRunners = import ../../forge/runners.nix { inherit lib; };
  # The main runner's entry. The 3h job timeout stays a nix literal,
  # deliberately not a runners.json field: it must stay below the nightly
  # sweep's 240-minute age.
  indriRunner = let entry = lib.findFirst (r: r.name == "indri-runner") null forgejoRunners; in
    if entry == null then throw "forge/runners.json: no runner named indri-runner - the main runner config render needs its entry" else entry;
  # The build runner's entry: the postActivation config render below reads
  # its labels and capacity from the declaration, like the main runner. The
  # 3h job timeout again stays a nix literal (the sweep's age threshold).
  indriBuildRunner = let entry = lib.findFirst (r: r.name == "indri-build") null forgejoRunners; in
    if entry == null then throw "forge/runners.json: no runner named indri-build - the build runner config render needs its entry" else entry;
  # ntfy topics (eblume/blumeops#1611): the rebuild watcher's topic comes from
  # the declaration, validated by ntfy/topics.nix; the read is relative to
  # this flake root, the same /etc/blumeops checkout constraint as
  # forge/runners.nix above.
  ntfyTopics = import ../../ntfy/topics.nix { inherit lib; };
  ntfyTopicsByName = lib.listToAttrs (map (t: { name = t.name; value = t; } ) ntfyTopics);
  forgejoRunnerCapacity = pkgs.writeText "forgejo-runner-capacity.prom"
    (lib.concatMapStrings (r: "forgejo_ci_runner_capacity{runner=\"${r.name}\"} ${toString r.capacity}\n")
      forgejoRunners);
  forgejoMetricsSrc = builtins.readFile ./mcquack-forgejo-metrics.sh;
  mcquackForgejoMetrics =
    assert lib.assertMsg (lib.hasInfix "@runnerCapacityFile@" forgejoMetricsSrc)
      "darwin/indri/mcquack-forgejo-metrics.sh lost its @runnerCapacityFile@ placeholder";
    pkgs.writeScript "mcquack-forgejo-metrics"
      (lib.replaceStrings [ "@runnerCapacityFile@" ] [ "${forgejoRunnerCapacity}" ] forgejoMetricsSrc);
  mcquackRunnerCacheSweep = pkgs.writeScript "mcquack-runner-cache-sweep" (builtins.readFile ./mcquack-runner-cache-sweep.sh);
  mcquackRunnerCachePrune = pkgs.writeScript "mcquack-runner-cache-prune" (builtins.readFile ./mcquack-runner-cache-prune.sh);
  mcquackJellyfinMetrics = pkgs.writeScript "mcquack-jellyfin-metrics" (builtins.readFile ./mcquack-jellyfin-metrics.sh);
  mcquackZotMetrics = pkgs.writeScript "mcquack-zot-metrics" (builtins.readFile ./mcquack-zot-metrics.sh);
  sifakaMounter = pkgs.writeScript "mount-sifaka" (builtins.readFile ./mount-sifaka.sh);
  mcquackIndriRebuildWatcher = pkgs.writeScript "mcquack-indri-rebuild-watcher" (builtins.readFile ./mcquack-indri-rebuild-watcher.sh);
  mcquackForgejoMirrorGuard = pkgs.writeScript "mcquack-forgejo-mirror-guard" (builtins.readFile ./mcquack-forgejo-mirror-guard.sh);
  # The build runner's colima engine host daemon (eblume/blumeops#1357):
  # nixpkgs colima, which wraps lima and qemu into its PATH itself.
  mcquackColimaBuild = pkgs.writeScript "mcquack-colima-build" (builtins.readFile ./mcquack-colima-build.sh);
  # The colima package the colima-build daemon runs. nixpkgs, not upstream's
  # flake: that flake hard-codes buildGo123Module, which cannot build current
  # colima releases (go.mod requires go >= 1.25).
  colimaBuild = pkgs.colima;
  # The build runner's colima profile (eblume/blumeops#1627): static - no
  # identity in it - so a checked-in file. postActivation installs it as
  # indri-build, drift-checked against a .applied baseline (see there), and
  # its colima stop leg uses the colimaBuild path above instead of the live
  # plist the ansible role had to parse.
  colimaBuildProfile = pkgs.writeText "colima-indri-build.yaml" (builtins.readFile ./colima-indri-build.yaml);
  # The docker CLI (client only, no daemon or VM). nixpkgs colima ships none,
  # yet `colima start` with runtime docker refuses a cold start without one on
  # PATH. It came from Docker Desktop's /usr/local/bin symlinks until that app
  # was removed (2026-10-06); the running VM hid the gap until the 2026-10-12
  # resize restarted it and every indri-build job queued.
  dockerClient = pkgs.docker-client;
  # The runner daemon's waiter: the pinned nix-darwin has no WaitForPaths
  # option, so the wait lives here. It idles until the generation renders the
  # runner config in postActivation (a human registers the runner first, so it
  # is absent until then)
  # AND colima exposes the docker socket - so pre-registration the daemon is
  # loaded but does nothing, and a fresh-boot empty VM disk (first start takes
  # minutes) merely delays the first job. Both correct, not faults.
  forgejoRunnerBuildWaiter = pkgs.writeScript "forgejo-runner-build-waiter" ''
    #!/bin/sh
    config=/Users/indri-build/forgejo-runner/config.yaml
    sock=/Users/indri-build/.colima/indri-build/docker.sock
    while [ ! -e "$config" ] || [ ! -e "$sock" ]; do
      sleep 30
    done
    exec "${pkgs.forgejo-runner}/bin/forgejo-runner" daemon --config "$config"
  '';
  # System argv0s are store paths, but system daemons load before /nix mounts,
  # and a first launch that fails EX_CONFIG is never retried by launchd
  # (eblume/blumeops#1225). Both build-runner daemons therefore exec this
  # non-store wrapper first (installed by the preActivation below), which
  # blocks until /nix mounts and then execs the store path it was launched as.
  # #1363's equivalent wrapper lives in erichblume's home, which indri-build
  # must not reach, so this one is shared in /usr/local/libexec (root-owned,
  # world-rx).
  nixWaitSystem = "/usr/local/libexec/mcquack.nix-wait";

  # argv0 of the pre-/nix wrapper (eblume/blumeops#1225): a stable non-store path that
  # blocks until /nix mounts, then execs the store path passed through by the agents.
  nixWait = "${config.system.primaryUserHome}/.local/bin/mcquack.nix-wait";
  # Where activation links the generation-owned mise config; mise follows
  # the symlink for reads and writes.
  miseConfigHome = "${config.system.primaryUserHome}/.config/mise/config.toml";

  # Caddy for the caddy unit (gandi = ACME DNS-01, l4 = TCP routes); in systemPackages so
  # the wrapper's system-profile exec is GC-rooted. See provision.md §Caddy.
  caddyWithPlugins = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/gandi@v1.1.0"
      "github.com/mholt/caddy-l4@v0.1.2"
    ];
    hash = "sha256-aEoxvsD7aYwZdORc3iLO7TQ9vzj3bpKWqJ8eIBD/bzY=";
  };
in
{
  imports = [
    ./invariants.nix
  ];

  # indri is an M1 Mac mini; pinning keeps the flake evaluable from off-box hosts.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # The caddy unit's binary, rooted in the generation's closure (see
  # caddyWithPlugins above). eblume/blumeops#1275.
  environment.systemPackages = [ caddyWithPlugins ];

  # nix-darwin must not manage Nix: Determinate owns daemon/store/config, and it aborts
  # otherwise (hard requirement). See [[indri]] §Nix.
  nix.enable = false;

  system.primaryUser = "erichblume";
  system.stateVersion = 6;

  programs.bash.enable = true;
  programs.fish.enable = true;

  # zsh off: login shell is Homebrew's fish, and the nix-darwin etc check
  # aborts on the stock /etc/zshrc + /etc/zprofile hashes. See [[provision]].
  programs.zsh.enable = false;

  # Remote Login declaratively (eblume/blumeops#1484 PR 3): nix-darwin's launchd
  # activation runs `launchctl enable` + `bootstrap` of system/com.openssh.sshd
  # when it is off - no Full Disk Access, no System Settings checkbox.
  services.openssh.enable = true;

  # nix-darwin's sshd drop-ins are store symlinks dangling until /nix mounts, and
  # sshd's Include of that directory exits 1 on a missing file - every connection
  # refused in the pre-Nix-Store boot window (mDNSResponder's /etc/resolver scan is
  # the other consumer that cannot tolerate a dangling link). All of them stay
  # off; the sshd policy and erichblume's authorized keys are written as REAL
  # files by the activation fragment below. See provision.md §First switch.
  services.openssh.hostKeys = [];   # keys exist on disk (2026-09-16); the stock
                                     # config finds them via its built-in HostKey
                                     # paths, and the 099 drop-in + keygen script
                                     # would dangle pre-/nix
  environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".enable = false;
  environment.etc."ssh/sshd_config.d/101-authorized-keys.conf".enable = false;

  # /etc/shells: the 26.05 flip removed the 25.05 generation's symlink
  # without re-declaring it; restore the stock list + fish (the login shell).
  environment.etc."shells".text = ''
    /bin/bash
    /bin/csh
    /bin/dash
    /bin/ksh
    /bin/sh
    /bin/tcsh
    /bin/zsh
    /opt/homebrew/bin/fish
  '';

  # Homebrew is generation-managed: every activation bundles the set below
  # (never cleaning up, upgrading, or auto-updating). tailscale is the SSH
  # path, and services.tailscale would load a second tailscaled beside the
  # brew root daemon, so the daemon stays brew-owned. eblume/blumeops#1538
  homebrew.enable = true;
  homebrew.brews = [
    "tailscale"
    # Adopted at 2026.4.11 (2026-10-12). bundle cannot pin a formula version
    # and onActivation.upgrade = false, so this never moves on its own;
    # a bump is `brew upgrade mise` + update the Toolchain doc.
    "mise"
    "fish"
  ];
  homebrew.onActivation.cleanup = "none";
  homebrew.onActivation.autoUpdate = false;
  homebrew.onActivation.upgrade = false;

  # Never sleep: on 2026-09-16 Amphetamine (the only sleep guard) segfaulted and darked
  # *.ops.eblu.me; Amphetamine stays as the second layer. See [[indri]] §Maintenance Notes.
  power.sleep.computer = "never";

  # --- unprivileged build runner user (eblume/blumeops#1357) ---
  # Second forgejo-runner, unprivileged by construction: created like every
  # nix-darwin user (sysadminctl), never in the admin group, so no sudo. The
  # home is 0700 both ways - erichblume cannot read the runner's persistent
  # state and the runner cannot read erichblume's home (issue acceptance); the
  # postActivation fragment makes the 0700 a hard error. The home is the
  # runner's persistent state (mise shims, caches), shared across every repo's
  # jobs until #1358 scopes it per-repo.
  # Own primary group, not the nix-darwin default gid 20 (staff): staff can
  # read erichblume's 0750 home, and host-mode jobs must not reach it. 501 is
  # erichblume's and 502 the forgejo account's on indri, so the pair is 503/503;
  # the system.checks block below refuses the switch if that is no longer true
  # on the box (no ssh from the pod to ask - check `dscl . -list /Users
  # UniqueID` and `dscl . -list /Groups PrimaryGroupID` there; the guard is
  # the preActivation block below).
  users.knownGroups = [ "indri-build" ];
  users.groups."indri-build" = { gid = 503; };
  users.knownUsers = [ "indri-build" ];
  # Hard constraint (eblume/blumeops#1358, decision 1): indri-build must never
  # be a trusted Nix user. Its Nix access is the multi-user Determinate daemon
  # (erichblume builds as an untrusted user already); builds run unsandboxed,
  # with network access, as the shared nixbld build user (daemon config read as
  # root 2026-10-08: sandbox = false, sandbox-fallback = true, trusted-users =
  # root, allowed-users = *). The flake neither adds it to any nix group nor
  # sets trusted-users. To widen: a deliberate PR changing Determinate's
  # /etc/nix/nix.custom.conf on the host, never this flake.
  users.users."indri-build" = {
    uid = 503;
    gid = 503;
    home = "/Users/indri-build";
    createHome = true;
    isHidden = true;
    # The module warns on `pkgs.bash` (no readline); the user never gets a
    # GUI session anyway - launchd jobs spawn bash.
    shell = pkgs.bashInteractive;
  };

  # --- mise toolchain (declarative) ---
  # indri's global mise config (was imperative in the indri play); change pins here, a
  # flake PR + `mise run provision-indri -- --tags rebuild`, never `mise use --global`.
  # The postActivation fragment links it into the user home; --rollback re-links the
  # previous generation's.
  environment.etc."mise/config.toml".text = ''
    [settings.go]
    # GOROOT export off: an exported GOROOT breaks GOTOOLCHAIN=auto switching.
    # See [[upgrade-forgejo]] §Go toolchain.
    set_goroot = false

    [tools]
    # Global go baseline (forgejo/zot source builds) + CI host tools the
    # runner's jobs resolve via shims; single source of truth on indri.
    go = "1.26.7"
    dagger = "0.21.9"
    prek = "0.4.14"
    flyctl = "0.4.118"
    argocd = "3.3.12"
    actionlint = "1.7.12"
    stylua = "2.4.1"
    shellcheck = "0.11.0"
    # Pinned: devpi's venv + CI resolve uv via the shim, and without a pin it
    # falls through to Homebrew's uv and drifts silently.
    uv = "0.11.7"
  '';

  # The build runner user's own global mise config (eblume/blumeops#1357):
  # the erichblume pins above (minus [settings.go], GOROOT handling is
  # erichblume-only) plus rust — indri-build's jobs run the macOS-native
  # cargo check directly on the host, and its home (0700) can't see
  # erichblume's rustup install. The postActivation fragment links it into
  # ~indri-build/.config/mise; --rollback re-links the previous generation's.
  environment.etc."mise/config-build-user.toml".text = ''
    [tools]
    # CI host tools the build runner's job steps resolve via shims; same
    # pins as the erichblume global config, the single source of truth.
    rust = "stable"
    go = "1.26.7"
    dagger = "0.21.9"
    prek = "0.4.14"
    flyctl = "0.4.118"
    argocd = "3.3.12"
    actionlint = "1.7.12"
    stylua = "2.4.1"
    shellcheck = "0.11.0"
    uv = "0.11.7"
  '';

  # The indri-build uid/gid pair check (eblume/blumeops#1357) and both pre-/nix
  # wrapper installs run in preActivation - the first activation block, ahead of
  # the launchd plist load, so the checks pass before user creation and the
  # wrappers exist before any daemon can exec them (eblume/blumeops#1225: a
  # first launch that fails EX_CONFIG is never retried by launchd). The system
  # wrapper is non-store, root-owned and world-rx in /usr/local/libexec and its
  # install fails the switch: #1363's gui-domain equivalent stays in
  # erichblume's home, which indri-build must not reach, and its install only
  # warns because gui-domain agents load at the console login. Both installs
  # stay root-owned (0755) so no user process can re-point the argv0s.
  system.activationScripts.preActivation.text = lib.mkAfter ''
    # The pair was picked off-box (501 erichblume, 502 the forgejo account,
    # per dscl on indri): refuse the switch rather than collide with an
    # account created since. sed (not a $var#prefix form): nix interpolates
    # $-braces inside this string, so the shell parameter expansion is avoided.
    # Both lookups need their `|| x=""`: activation runs under set -e and
    # pipefail, and dscl exits 56 for a missing record - which is every
    # first deploy, the one this guard exists for.
    u=$(id -u indri-build 2> /dev/null) || u=""
    if [[ -n "$u" && "$u" -ne 503 ]]; then
      printf >&2 'error: indri-build exists with uid %s, expected 503 - update the pair in darwin/indri/configuration.nix\n' "$u"
      exit 1
    fi
    if [[ -z "$u" ]] && dscl . -list /Users UniqueID 2> /dev/null | grep -qw 503; then
      printf >&2 'error: uid 503 is already taken on indri - update the pair in darwin/indri/configuration.nix\n'
      exit 1
    fi
    g=$(dscl . -read /Groups/indri-build PrimaryGroupID 2> /dev/null | sed 's/^PrimaryGroupID: //') || g=""
    if [[ -n "$g" && "$g" != 503 ]]; then
      printf >&2 'error: group indri-build exists with gid %s, expected 503 - update the pair in darwin/indri/configuration.nix\n' "$g"
      exit 1
    fi
    if [[ -z "$g" ]] && dscl . -list /Groups PrimaryGroupID 2> /dev/null | grep -qw 503; then
      printf >&2 'error: gid 503 is already taken on indri - update the pair in darwin/indri/configuration.nix\n'
      exit 1
    fi

    # #1363 user-home wrapper, warning-only: its gui-domain agents load at the
    # console login, after /nix mounts, so a failed install degrades to one
    # missed reload, never a dead boot. mktemp + mv keeps the write
    # symlink-proof; the heredoc terminator must stay at column 0 (nix strips
    # the indented string to its least-indented line) - do not re-indent it.
    if [[ -d ${lib.escapeShellArg config.system.primaryUserHome} ]]; then
      {
        mkdir -p ${lib.escapeShellArg "${config.system.primaryUserHome}/.local/bin"} &&
        tmp=$(mktemp ${lib.escapeShellArg "${nixWait}.XXXXXX"}) &&
        cat > "$tmp" <<'MCQUACK_NIX_WAIT'
#!/bin/bash
# Blocks until the /nix store volume is mounted, then execs "$@" - a stable
# non-store argv0 so the /nix-backed user agents survive the pre-/nix login
# window. Owned by nix-darwin activation; do not edit.
# See blumeops darwin/indri/configuration.nix and docs/how-to/indri/provision.md.
t=0
while [ ! -d /nix/store ]; do
  t=$((t + 1))
  [ $((t % 120)) -eq 0 ] && printf 'nix-wait: /nix/store still not mounted after %ss\n' "$t" >&2
  sleep 0.5
done
exec "$@"
MCQUACK_NIX_WAIT
        chmod 0755 "$tmp" &&
        mv -f "$tmp" ${lib.escapeShellArg nixWait}
      } || printf >&2 'warning: indri nix-wait wrapper: could not install ${lib.escapeShellArg nixWait}\n'
      :
    else
      printf >&2 'warning: indri nix-wait wrapper: ${lib.escapeShellArg config.system.primaryUserHome} missing, skipped\n'
      :
    fi

    # The system wrapper (fail-closed; it is the last line of this block, so a
    # failed install fails the switch) - see the nixWaitSystem note in the let
    # block. Same mktemp / column-0-heredoc constraints as above. tmp= first:
    # the user block's tmp is stale here, and a failed mkdir/mktemp must not
    # leave the final mv pointing at it.
    tmp=
    mkdir -p /usr/local/libexec &&
    tmp=$(mktemp /usr/local/libexec/.mcquack.nix-wait.XXXXXX) &&
    cat > "$tmp" <<'MCQUACK_NIX_WAIT_SYSTEM'
#!/bin/sh
# Blocks until the /nix store volume is mounted, then execs "$@" - a stable
# non-store argv0 so the /nix-backed system daemons survive the pre-/nix
# window. Owned by nix-darwin activation; do not edit.
while [ ! -d /nix/store ]; do
  sleep 0.5
done
exec "$@"
MCQUACK_NIX_WAIT_SYSTEM
    chmod 0755 "$tmp" &&
    mv -f "$tmp" ${lib.escapeShellArg nixWaitSystem}
  '';

  # The main runner's identity check (eblume/blumeops#1528), in the checks
  # slot: within the activation script it runs ahead of every install
  # (users, launchd, the /run/current-system re-point at the tail), so a
  # missing identity fails the switch before anything is installed. The
  # system profile was already moved by darwin-rebuild's nix-env --set
  # before the activation script runs, so it stays on the un-activated
  # generation until the next good switch heals it. It cannot live in
  # postActivation - by then the installs have already been applied, and a
  # late exit would skip the /run/current-system tail, leaving the host
  # half-switched. The rebuild watcher posts only non-zero verdicts, so
  # this failure is how the warning gets seen.
  system.activationScripts.checks.text = ''
    missing=
    for f in uuid token mise-github-token; do
      [[ -r /Users/erichblume/forgejo-runner/identity/$f && -s /Users/erichblume/forgejo-runner/identity/$f ]] || missing="$missing $f"
    done
    if [[ -n "$missing" ]]; then
      printf 'error: forgejo-runner identity incomplete (missing or empty:%s) - failing the switch before anything changes; seed it with `mise run seed-secrets indri`, then re-apply (`mise run provision-indri -- --tags rebuild`)\n' "$missing" >&2
      exit 1
    fi
    if [[ ! -r ${hephHubSubFile} || ! -s ${hephHubSubFile} ]]; then
      printf 'error: heph authorized-sub file missing or empty at %s - failing the switch before anything changes; seed it with `mise run seed-secrets indri`, then re-apply (`mise run provision-indri -- --tags rebuild`)\n' "${hephHubSubFile}" >&2
      exit 1
    fi
  '';

  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [[ -d ${lib.escapeShellArg config.system.primaryUserHome} ]]; then
      {
        mkdir -p ${lib.escapeShellArg "${config.system.primaryUserHome}/.config/mise"} &&
        ln -sfn ${lib.escapeShellArg "/etc/static/mise/config.toml"} ${lib.escapeShellArg miseConfigHome} &&
        chown -h erichblume:staff ${lib.escapeShellArg miseConfigHome}
      } || printf >&2 'warning: indri mise config: could not link ${lib.escapeShellArg miseConfigHome}\n'
      :
    else
      printf >&2 'warning: indri mise config: ${lib.escapeShellArg config.system.primaryUserHome} missing, skipped\n'
      :
    fi

    # indri-build runner (eblume/blumeops#1357): lock the home to 0700 and
    # lay out the daemon directories. Root touches only the home directory
    # itself - everything inside it is created as indri-build (sudo -u), so a
    # symlink planted by the untrusted user cannot redirect a root write.
    if id indri-build >/dev/null 2>&1; then
      # 0700 is the acceptance gate, not a nicety: createhomedir's template
      # is 0755, and a readable home breaks the guarantee both ways.
      chmod 0700 /Users/indri-build || {
        printf >&2 'error: could not chmod 0700 /Users/indri-build\n'
        exit 1
      }
      # The daemons' log dir and the runner's working dir + colima profile
      # dir must exist for launchd to start the jobs. As the user: the home
      # is attacker-controlled, and root's mkdir -p / chown -R would follow
      # a planted symlink. (The runner's identity files are not created here:
      # they are root-owned under /usr/local/etc/forgejo-runner-build/identity/,
      # outside the home, and seated by seed-secrets - the daemon reads only
      # the rendered config.yaml.)
      sudo -u indri-build mkdir -p /Users/indri-build/Library/Logs \
                                   /Users/indri-build/forgejo-runner \
                                   /Users/indri-build/.colima/indri-build &&
      sudo -u indri-build chown -R indri-build:indri-build \
                             /Users/indri-build/Library/Logs \
                             /Users/indri-build/forgejo-runner \
                             /Users/indri-build/.colima
      # The build user's own mise config (identical [tools] pins, no
      # [settings.go]); --rollback re-links the previous generation's.
      # As the user: .config is attacker-controlled.
      {
        sudo -u indri-build mkdir -p /Users/indri-build/.config/mise &&
        sudo -u indri-build ln -sfn /etc/static/mise/config-build-user.toml /Users/indri-build/.config/mise/config.toml
      } || printf >&2 'warning: indri-build mise config: could not link /Users/indri-build/.config/mise/config.toml\n'
      :
    fi

    # Main forgejo runner config (eblume/blumeops#1528): labels and capacity
    # from forge/runners.json (via the indriRunner binding above), identity
    # from the files `mise run seed-secrets indri` seats under the identity
    # dir and declares in darwin/indri/secrets.json. Presence is enforced in
    # the activationScripts.checks block above; the else branch below only
    # fires if a file vanished after the check, and keeps the existing config
    # without restarting the runner. Only this kickstart and the seed-secrets
    # restart leg restart the main runner; nix-darwin does not reload an
    # unchanged agent.
    runner_home=/Users/erichblume/forgejo-runner
    runner_identity="$runner_home/identity"
    runner_config="$runner_home/config.yaml"
    # The parent home is the daemon's WorkingDirectory (job scratch): a
    # fresh host would otherwise get a root-owned 0755 dir here.
    mkdir -p "$runner_home" &&
    chown erichblume:staff "$runner_home" &&
    chmod 0700 "$runner_home" &&
    mkdir -p "$runner_identity" &&
    chown erichblume:staff "$runner_identity" &&
    chmod 0700 "$runner_identity"
    runner_uuid=
    runner_token=
    runner_pat=
    if [[ -r "$runner_identity/uuid" && -r "$runner_identity/token" && -r "$runner_identity/mise-github-token" ]]; then
      runner_uuid=$(cat "$runner_identity/uuid")
      runner_token=$(cat "$runner_identity/token")
      runner_pat=$(cat "$runner_identity/mise-github-token")
    fi
    if [[ -n "$runner_uuid" && -n "$runner_token" && -n "$runner_pat" ]]; then
      tmp=$(mktemp /Users/erichblume/forgejo-runner/.config.yaml.XXXXXX) &&
      cat > "$tmp" <<CFG
# Generated by the indri nix-darwin generation (postActivation) - do not
# edit by hand. Identity: the files under /Users/erichblume/forgejo-runner/
# identity/ (seated by seed-secrets, declared in darwin/indri/secrets.json);
# labels and capacity: forge/runners.json. eblume/blumeops#1528.
#
# Host-mode jobs: jobs run directly as erichblume with indri's
# mise-managed toolchain - no job container, no runner-job-image, no
# container engine on this runner.
log:
  level: info

runner:
  capacity: ${toString indriRunner.capacity}
  timeout: 3h
  shutdown_timeout: 3h
  # Env vars injected into all jobs
  envs:
    TZ: America/Los_Angeles
    # Zero-permission GitHub PAT (public read only). mise prefers
    # MISE_GITHUB_TOKEN over the forge-injected GITHUB_TOKEN (first
    # non-empty of MISE_GITHUB_TOKEN, GITHUB_API_TOKEN, GITHUB_TOKEN
    # wins), so tool resolution authenticates to api.github.com instead
    # of offering forge's job token. Readable by every job this runner
    # builds - nothing with a scope may ever land here.
    MISE_GITHUB_TOKEN: $runner_pat

server:
  connections:
    forgejo:
      url: https://forge.ops.eblu.me/
      uuid: $runner_uuid
      token: $runner_token
      labels:
${lib.concatMapStringsSep "\n" (l: "        - ${l}:host") indriRunner.labels}
CFG
      chown erichblume:staff "$tmp" &&
      chmod 0600 "$tmp"
      if cmp -s "$tmp" "$runner_config"; then
        rm -f "$tmp"
      else
        mv -f "$tmp" "$runner_config"
        uid=$(id -u erichblume)
        state=
        if launchctl kickstart -k gui/"$uid"/mcquack.eblume.forgejo-runner 2> /dev/null; then
          for _ in 1 2 3 4 5; do
            state=$(launchctl print gui/"$uid"/mcquack.eblume.forgejo-runner 2> /dev/null | sed -n 's/^[[:space:]]*state = //p' | head -n1 || true)
            case "$state" in
              "" | waiting | "spawn scheduled") sleep 1 ;;
              *) break ;;
            esac
          done
          case "$state" in
            running | "spawn scheduled")
              :
            ;;
            "")
              printf 'warning: forgejo-runner kickstarted but launchctl print shows no state - the label may not be loaded in the gui domain (user session absent?)\n' >&2
            ;;
            *)
              printf 'warning: forgejo-runner kickstarted but reports state %q - check /Users/erichblume/Library/Logs/mcquack.forgejo-runner.err.log\n' "$state" >&2
            ;;
          esac
        else
          printf 'warning: forgejo-runner config installed but kickstart failed - the gui-domain label is not loaded (user session absent?); the runner keeps its current values until its next (re)load\n' >&2
        fi
      fi
      # Re-assert owner and mode unconditionally: the install only sees
      # content, so a hand edit of mode or owner would otherwise persist
      # across every cmp-equal apply.
      chown erichblume:staff "$runner_config" &&
      chmod 0600 "$runner_config"
    else
      missing=
      for f in uuid token mise-github-token; do
        [[ -r "$runner_identity/$f" && -s "$runner_identity/$f" ]] || missing="$missing $f"
      done
      printf 'warning: forgejo-runner identity incomplete (missing or empty:%s) - keeping the existing %s and not restarting the runner; seed it with `mise run seed-secrets indri`, then re-apply (`mise run provision-indri -- --tags rebuild`)\n' "$missing" "$runner_config" >&2
    fi

    # Build forgejo runner config (eblume/blumeops#1627): labels and
    # capacity from forge/runners.json (via the indriBuildRunner binding),
    # identity from the files `mise run seed-secrets indri` seats under the
    # identity dir and declares in darwin/indri/secrets.json. Unlike the
    # main runner there is no checks-slot hard fail: the build runner is
    # optional, and pre-registration renders nothing and restarts nothing -
    # the daemons' wait loops idle until the files exist.
    build_home=/Users/indri-build/forgejo-runner
    # Identity lives root-owned under /usr/local/etc/forgejo-runner-build/
    # identity/ (declared in darwin/indri/secrets.json), not in the home:
    # only the generation reads it (as root, to render the config), the
    # indri-build daemon reads only config.yaml, and the dir is created by
    # seed-secrets on first run (root:wheel, outside the attacker-controlled
    # home - the same way ringtail's root-owned /etc secrets are seated).
    build_identity=/usr/local/etc/forgejo-runner-build/identity
    build_config="$build_home/config.yaml"
    build_uuid=
    build_token=
    build_pat=
    if [[ -r "$build_identity/uuid" && -r "$build_identity/token" && -r "$build_identity/mise-github-token" ]]; then
      build_uuid=$(cat "$build_identity/uuid")
      build_token=$(cat "$build_identity/token")
      build_pat=$(cat "$build_identity/mise-github-token")
    fi
    # Root-owned dir outside the home, shared by the identity files (the
    # identity/ subdir, seated by seed-secrets), the config render below, and
    # the colima .applied baseline; it exists only once the runner has at
    # least a uuid (the gate the colima tasks had). The config write into the
    # attacker-controlled home still happens as indri-build (install unlinks
    # and recreates, so a planted symlink cannot redirect it) - the same
    # split the ansible role had.
    if [[ -r "$build_identity/uuid" && -s "$build_identity/uuid" ]]; then
      mkdir -p /usr/local/etc/forgejo-runner-build &&
      chown root:indri-build /usr/local/etc/forgejo-runner-build &&
      chmod 0750 /usr/local/etc/forgejo-runner-build
    fi
    if [[ -n "$build_uuid" && -n "$build_token" && -n "$build_pat" ]]; then
      tmp=$(mktemp /usr/local/etc/forgejo-runner-build/.config.yaml.XXXXXX) &&
      cat > "$tmp" <<CFG
# Generated by the indri nix-darwin generation (postActivation) - do not
# edit by hand. Identity: the files under /usr/local/etc/forgejo-runner-build/
# identity/ (root-owned, seated by seed-secrets, declared in darwin/indri/
# secrets.json); labels and capacity: forge/runners.json. eblume/blumeops#1627.
#
# Second, unprivileged runner: jobs run as the dedicated indri-build macOS
# user (no sudo) and reach containers through the colima VM at
# ~indri-build/.colima/indri-build/docker.sock. Tool resolution uses
# indri-build's own mise config with the shared zero-permission
# forge-ci-github-pat.
log:
  level: info

runner:
  capacity: ${toString indriBuildRunner.capacity}
  timeout: 3h
  shutdown_timeout: 3h
  # Env vars injected into all jobs
  envs:
    TZ: America/Los_Angeles
    # Zero-permission GitHub PAT (public read only) for the build runner's
    # own mise resolution - same value and rule as the main runner's.
    MISE_GITHUB_TOKEN: $build_pat

server:
  connections:
    forgejo:
      url: https://forge.ops.eblu.me/
      uuid: $build_uuid
      token: $build_token
      labels:
${lib.concatMapStringsSep "\n" (l: "        - ${l}:host") indriBuildRunner.labels}
CFG
      chown root:indri-build "$tmp" &&
      chmod 0640 "$tmp"
      if cmp -s "$tmp" "$build_config"; then
        rm -f "$tmp"
      else
        sudo -u indri-build /bin/sh -c 'cd / && /usr/bin/install -m 0600 "$1" "$2"' _ "$tmp" "$build_config" &&
        rm -f "$tmp"
        state=
        if launchctl kickstart -k system/mcquack.eblume.forgejo-runner-build 2> /dev/null; then
          for _ in 1 2 3 4 5; do
            state=$(launchctl print system/mcquack.eblume.forgejo-runner-build 2> /dev/null | sed -n 's/^[[:space:]]*state = //p' | head -n1 || true)
            case "$state" in
              "" | waiting | "spawn scheduled") sleep 1 ;;
              *) break ;;
            esac
          done
          case "$state" in
            running | "spawn scheduled")
              :
            ;;
            "")
              printf 'warning: forgejo-runner-build kickstarted but launchctl print shows no state - the label may not be loaded in the system domain\n' >&2
            ;;
            *)
              printf 'warning: forgejo-runner-build kickstarted but reports state %q - check /Users/indri-build/Library/Logs/mcquack.forgejo-runner-build.err.log\n' "$state" >&2
            ;;
          esac
        else
          printf 'warning: forgejo-runner-build config installed but kickstart failed - the system-domain label is not loaded; the runner keeps its current values until its next (re)load\n' >&2
        fi
      fi
      # Re-assert owner and mode unconditionally: the install only sees
      # content, so a hand edit of mode or owner would otherwise persist
      # across every cmp-equal apply.
      sudo -u indri-build chown indri-build:indri-build "$build_config" &&
      sudo -u indri-build chmod 0600 "$build_config"
    else
      missing=
      for f in uuid token mise-github-token; do
        [[ -r "$build_identity/$f" && -s "$build_identity/$f" ]] || missing="$missing $f"
      done
      printf 'warning: forgejo-runner-build identity incomplete (missing or empty:%s) - keeping the existing %s and not restarting the runner; seed it with `mise run seed-secrets indri`, then re-apply (`mise run provision-indri -- --tags rebuild`)\n' "$missing" "$build_config" >&2
    fi

    # Build runner colima profile (eblume/blumeops#1627): the static file
    # above is installed twice as indri-build - the colima template (fresh
    # instances, including a rebuilt VM) and the profile dir (existing
    # instances), because colima seeds a new instance from the template but
    # reads the profile dir for an existing one. colima rewrites the live
    # profile with its own defaulted keys on every start
    # (eblume/blumeops#1522), so drift is measured against the last render
    # this generation installed (the .applied baseline, kept where the
    # ansible role kept it), not the live file; baseline absence counts as
    # drift. Gated on the uuid identity file like the role's tasks were:
    # pre-registration the profile is absent and the colima-build daemon
    # idles in its wait loop.
    if [[ -r "$build_identity/uuid" && -s "$build_identity/uuid" ]]; then
      colima_applied=/usr/local/etc/forgejo-runner-build/colima.yaml.applied
      if ! cmp -s "${colimaBuildProfile}" "$colima_applied" 2> /dev/null; then
        sudo -u indri-build /bin/sh -c 'cd / && for _p in "$1" "$2"; do mkdir -p "$(dirname "$_p")"; done && /usr/bin/install -m 0600 "$0" "$1" && /usr/bin/install -m 0600 "$0" "$2"' \
          "${colimaBuildProfile}" \
          /Users/indri-build/.colima/_templates/default.yaml \
          /Users/indri-build/.colima/indri-build/colima.yaml
        # cpu/memory/mounts apply only when the VM boots, so stop it: the
        # colima-build daemon's wrapper exits when the VM stops and
        # KeepAlive re-runs colima start, which reads the new profile. The
        # colima binary is the nixpkgs one the daemon runs - the generation
        # knows its own store path, which the ansible role had to read back
        # from the live plist. A not-yet-running VM makes stop a no-op.
        if sudo -n -H -u indri-build /usr/bin/env -u SSH_AUTH_SOCK PATH="${colimaBuild}/bin:/usr/bin:/bin:/usr/sbin:/sbin" colima stop --profile indri-build; then
          install -m 0640 "${colimaBuildProfile}" "$colima_applied" &&
          chown root:indri-build "$colima_applied" &&
          chmod 0640 "$colima_applied"
        else
          # Without a recorded baseline the next switch retries the stop:
          # the profile is installed but the VM keeps the old settings
          # until it next boots.
          printf 'warning: colima stop --profile indri-build failed - the VM keeps the previous profile; the .applied baseline is not recorded, so the next switch retries\n' >&2
        fi
      fi
    fi

    # Build runner docker client config repair (eblume/blumeops#1382): the
    # dagger CLI runs as indri-build on the host and re-reads this file for
    # every registry-credential lookup, execing the configured credential
    # helper on the host - a Docker-Desktop-era helper reference (the
    # helper no longer exists) breaks every uncached image pull. The
    # repair strips the helper keys and keeps the rest (runtime auths are
    # legitimate); the next dagger run picks it up without a VM restart.
    # The file can carry registry credentials, so it is never printed.
    if [[ -r "$build_identity/uuid" && -s "$build_identity/uuid" ]]; then
      if sudo -n -H -u indri-build /bin/sh -c '
        f="$1"
        cd /
        test -f "$f" || exit 1
        ${pkgs.python3}/bin/python3 - "$f" << "PY"
import json, os, sys, tempfile

p = sys.argv[1]
try:
    with open(p) as fh:
        cfg = json.load(fh)
    assert isinstance(cfg, dict)
except Exception:
    sys.exit(2)
if "credsStore" not in cfg and "credHelpers" not in cfg:
    sys.exit(0)
for k in ("credsStore", "credHelpers"):
    if k in cfg:
        del cfg[k]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p))
with os.fdopen(fd, "w") as fh:
    json.dump(cfg, fh, indent=4)
    fh.write("\n")
os.replace(tmp, p)
PY
        ' _ /Users/indri-build/.docker/config.json; then
        :
      else
        printf 'warning: could not inspect or repair the build runner docker config (absent, unreadable, or malformed) - the role used to fail the provision here\n' >&2
      fi
    fi
  '';

  # sshd policy + erichblume's authorized keys (eblume/blumeops#1484 PR 3), in
  # the extraActivation slot: it runs before the launchd slot, so the real
  # files exist before sshd is bootstrapped on the first switch. Real files,
  # not store symlinks: sshd's Include of /etc/ssh/sshd_config.d exits 1 on a
  # dangling link, refusing every connection until the Nix Store mounts, while
  # a real file is valid in that window. The AuthorizedKeysCommand (nix-darwin's
  # idiom for authorized keys) reads /etc/ssh/nix_authorized_keys.d/%u IN
  # ADDITION to each user's own authorized_keys, so a human-managed key file
  # keeps working. The drop-in is swapped in, and kept only if sshd -t
  # accepts it (the previous one restored on rejection): macOS runs sshd per connection,
  # so a bad config left in place would refuse every new login. The drop-in
  # sorts before Apple's 100-macos.conf: sshd honors the first value obtained
  # for a keyword.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    mkdir -p /etc/ssh/sshd_config.d /etc/ssh/nix_authorized_keys.d
    chmod 0755 /etc/ssh/nix_authorized_keys.d

    sshd_target=/etc/ssh/sshd_config.d/050-indri.conf
    tmp=$(mktemp /etc/ssh/sshd_config.d/.050-indri.conf.XXXXXX) &&
    cat > "$tmp" <<'SSHD_POLICY'
# indri sshd policy (eblume/blumeops#1484 PR 3). Real file written by
# nix-darwin activation - a store symlink here would dangle pre-/nix and
# sshd's Include of this directory would refuse every connection.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers erichblume
AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u
AuthorizedKeysCommandUser _sshd
SSHD_POLICY
    chmod 0644 "$tmp"
    if cmp -s "$tmp" "$sshd_target"; then
      rm -f "$tmp"
    else
      # The drop-in is live config the instant it lands: back up, swap,
      # validate, and restore the backup if sshd refuses it.
      if [ -f "$sshd_target" ]; then
        cp -p "$sshd_target" "$sshd_target.nix-darwin-backup"
      else
        rm -f "$sshd_target.nix-darwin-backup"
      fi
      mv -f "$tmp" "$sshd_target"
      if ! /usr/sbin/sshd -t; then
        printf >&2 'error: sshd rejected the new configuration (sshd -t); restoring previous drop-in\n'
        if [ -f "$sshd_target.nix-darwin-backup" ]; then
          mv -f "$sshd_target.nix-darwin-backup" "$sshd_target" || {
            printf >&2 'error: could not restore previous drop-in\n'
            exit 1
          }
        else
          rm -f "$sshd_target"
        fi
        exit 1
      fi
      rm -f "$sshd_target.nix-darwin-backup"
    fi

    keys_target=/etc/ssh/nix_authorized_keys.d/erichblume
    tmp=$(mktemp /etc/ssh/nix_authorized_keys.d/.erichblume.XXXXXX) &&
    cat > "$tmp" <<'AUTHORIZED_KEYS'
# erichblume's 1Password "SSH - Personal" public key - the same key ringtail
# authorizes for eblume (nixos/ringtail/configuration.nix, users.users.eblume).
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILmh1SSCdDAyu3vkSQH7kAXEPDi8APyjo9JXDTjtha2j
AUTHORIZED_KEYS
    chmod 0644 "$tmp"
    if cmp -s "$tmp" "$keys_target"; then
      rm -f "$tmp"
    else
      mv -f "$tmp" "$keys_target"
    fi
  '';

  # --- launchd label convention for nix-managed services ---
  # Every nix-managed agent uses Label = "mcquack.eblume.<svc>" (jellyfin alone keeps the
  # role's historical mcquack.jellyfin); logrotate's globs, alloy's tails and the restart
  # runbook key on label, plist path and log names - never rename, and a change swaps the
  # plist in place (one reload, never dual-loaded). Rollback: darwin-rebuild --rollback
  # first, then the role with its skip gate flipped - never ansible first.
  # See [[provision]] §Rolling back a service flip.

  # logrotate: first service moved (PR 2); generation and (default-skipped) role own one
  # plist and swap in place - the role's only job left is the rollback re-write.
  launchd.user.agents."mcquack.eblume.logrotate".serviceConfig = {
    Label = "mcquack.eblume.logrotate";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackLogrotate}" ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.err.log";
  };

  # sifaka-mounter (eblume/blumeops#1323): replaces the AutoMounter app - the only
  # thing that kept the sifaka SMB shares mounted. argv[0] is the pre-/nix wrapper
  # (eblume/blumeops#1225) - a store argv0 fails EX_CONFIG once and launchd never
  # retries it (no KeepAlive/interval retry); the wrapper blocks until /nix mounts
  # instead. Credentials stay in the login
  # Keychain; a missing entry shows up as sifaka_share_mounted == 0, never a GUI
  # dialog (the script times out and kills the osascript prompt).
  launchd.user.agents."mcquack.eblume.sifaka-mounter".serviceConfig = {
    Label = "mcquack.eblume.sifaka-mounter";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${sifakaMounter}" ];
    RunAtLoad = true;
    StartInterval = 60;
    # Borgmatic runs unattended at 02:00; guarantee one fresh pass just before it.
    StartCalendarInterval = [ { Hour = 1; Minute = 45; } ];
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StandardOutPath = "/opt/homebrew/var/log/mcquack.sifaka-mounter.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.sifaka-mounter.err.log";
  };

  # indri-rebuild-watcher (eblume/blumeops#1525): alerts on any detached-switch
  # verdict sidecar other than 0/superseded, so a failed apply ntfys on its own.
  launchd.user.agents."mcquack.eblume.indri-rebuild-watcher".serviceConfig = {
    Label = "mcquack.eblume.indri-rebuild-watcher";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackIndriRebuildWatcher}" ];
    StartInterval = 60;
    RunAtLoad = true;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
      # The topic comes from ntfy/topics.json (eblume/blumeops#1611); the watcher's own NTFY_TOPIC default is the fallback for its tests.
      NTFY_TOPIC = "https://ntfy.ops.eblu.me/${ntfyTopicsByName."ops-approvals".name}";
    };
    StandardOutPath = "/opt/homebrew/var/log/mcquack.indri-rebuild-watcher.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.indri-rebuild-watcher.err.log";
  };

  # The four *-metrics collectors (PR 4): same labels, plist paths, .prom files and logs
  # as the roles - in-place swap, so alloy and TextfileStale are unaffected. API key files
  # stay controller-side op placement (the roles' key-file tasks are ungated).
  launchd.user.agents."mcquack.eblume.borgmatic-metrics".serviceConfig = {
    Label = "mcquack.eblume.borgmatic-metrics";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackBorgmaticMetrics}" ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/mcquack.borgmatic-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.borgmatic-metrics.err.log";
  };

  launchd.user.agents."mcquack.eblume.forgejo-metrics".serviceConfig = {
    Label = "mcquack.eblume.forgejo-metrics";
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackForgejoMetrics}" ];
    StartInterval = 60;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/mcquack.forgejo-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.forgejo-metrics.err.log";
  };

  # forgejo-mirror-guard (eblume/blumeops#1629): a push-mirror remote with a
  # fetch refspec on the forge's bare repos would let an in-flight sync rewrite
  # the local ref (that is how blumeops main was rewound); the reflog check
  # catches any non-FF main move. ntfys ops-approvals, 0/1 textfile metrics.
  launchd.user.agents."mcquack.eblume.forgejo-mirror-guard".serviceConfig = {
    Label = "mcquack.eblume.forgejo-mirror-guard";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackForgejoMirrorGuard}" ];
    StartInterval = 600;
    RunAtLoad = true;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
      NTFY_TOPIC = "https://ntfy.ops.eblu.me/${ntfyTopicsByName."ops-approvals".name}";
    };
    StandardOutPath = "/opt/homebrew/var/log/mcquack.forgejo-mirror-guard.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.forgejo-mirror-guard.err.log";
  };

  # jellyfin keeps the ansible role's log names (no mcquack. prefix).
  launchd.user.agents."mcquack.eblume.jellyfin-metrics".serviceConfig = {
    Label = "mcquack.eblume.jellyfin-metrics";
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackJellyfinMetrics}" ];
    StartInterval = 60;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/jellyfin-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/jellyfin-metrics.err.log";
  };

  launchd.user.agents."mcquack.eblume.zot-metrics".serviceConfig = {
    Label = "mcquack.eblume.zot-metrics";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackZotMetrics}" ];
    StartInterval = 60;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/mcquack.zot-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.zot-metrics.err.log";
  };

  # zot (PR 5): first real daemon - with the unit unloaded the registry and every
  # pull/push behind it are down. Binary stays the source build; config stays
  # role-rendered (the gate covers the plist + load only). See provision.md §Zot registry.
  launchd.user.agents."mcquack.eblume.zot".serviceConfig = {
    Label = "mcquack.eblume.zot";
    ProgramArguments = [
      "/Users/erichblume/code/3rd/zot/bin/zot-darwin-arm64"
      "serve"
      "/Users/erichblume/.config/zot/config.json"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      PATH = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.zot.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.zot.err.log";
  };

  # The heph hub (eblume/blumeops#1655): same label, plist path and log paths
  # the ansible role rendered, so the switch swaps the plist in place (one
  # reload, never dual-loaded). argv0 is the pre-/nix wrapper per invariants.nix
  # (eblume/blumeops#1225); the store wrapper carries the --authorized-sub argv
  # the role's op-read leg used to inject, from the seeded on-host file (the
  # flake reads no vault). The PWA checkout stays role-managed - the store is
  # read-only, and the web root must stay a mutable git checkout with its
  # pwa-version.js stamp. Rollback per [[provision]] §Rolling back a service
  # flip.
  launchd.user.agents."mcquack.eblume.heph".serviceConfig = {
    Label = "mcquack.eblume.heph";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${hephHubRunner}/bin/mcquack-heph-hub" ];
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      PATH = "/Users/erichblume/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      HOME = "/Users/erichblume";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.heph.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.heph.err.log";
  };

  launchd.user.agents."mcquack.eblume.heph-cargo-bin-cleanup".serviceConfig = {
    Label = "mcquack.eblume.heph-cargo-bin-cleanup";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${hephCargoBinCleanup}/bin/mcquack-heph-cargo-bin-cleanup" ];
    RunAtLoad = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.heph-cargo-bin-cleanup.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.heph-cargo-bin-cleanup.err.log";
  };

  # caddy (PR 6): fronts every *.ops.eblu.me endpoint + L4 route; with the unit unloaded
  # the forge API/ssh, the registry and CI are down. ProgramArguments[0] stays the
  # on-disk wrapper, not a store path (EX_CONFIG in the pre-/nix window,
  # eblume/blumeops#1225); Caddyfile, wrapper and token stay role-rendered.
  # See provision.md §Caddy.
  launchd.user.agents."mcquack.eblume.caddy".serviceConfig = {
    Label = "mcquack.eblume.caddy";
    ProgramArguments = [ "/Users/erichblume/.config/caddy/caddy-wrapper.sh" ];
    WorkingDirectory = "/Users/erichblume/.local/share/caddy";
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      XDG_DATA_HOME = "/Users/erichblume/.local/share";
      XDG_CONFIG_HOME = "/Users/erichblume/.config";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.caddy.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.caddy.err.log";
  };

  # forgejo-runner: executes every `indri`-label CI job (nixpkgs binary;
  # upstream ships no darwin release). Unloaded = indri-label jobs queue on
  # forge; everything else stays up. config.yaml is rendered by the
  # postActivation above (eblume/blumeops#1528).
  launchd.user.agents."mcquack.eblume.forgejo-runner".serviceConfig = {
    Label = "mcquack.eblume.forgejo-runner";
    ProgramArguments = [ "${nixWait}" ] ++ [
      "${pkgs.forgejo-runner}/bin/forgejo-runner"
      "daemon"
      "--config"
      "/Users/erichblume/forgejo-runner/config.yaml"
    ];
    WorkingDirectory = "/Users/erichblume/forgejo-runner";
    RunAtLoad = true;
    KeepAlive = true;
    # launchd clamps ExitTimeOut to 60 s in the per-user gui domain (measured on macOS
    # 26) - this mirrors the role's rollback re-write, it is not a drain window.
    # AbandonProcessGroup is what matters: without it a stop kills the process group and
    # takes a detached darwin-rebuild mid-activation. eblume/blumeops#1266.
    ExitTimeOut = 10800;
    AbandonProcessGroup = true;
    EnvironmentVariables = {
      # mise shims first (host-mode jobs use indri's mise toolchain); nix default profile
      # last so the flake check finds `nix` unshadowed.
      PATH = "/Users/erichblume/.local/share/mise/shims:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
      HOME = "/Users/erichblume";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.forgejo-runner.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.forgejo-runner.err.log";
  };

  # Cache maintenance for the main runner (eblume/blumeops#1528 PR 3): nightly
  # sweep, monthly prune. The sweep's log paths are alloy's tail keys and
  # Loki's ship name — never rename.
  launchd.user.agents."mcquack.eblume.runner-cache-sweep".serviceConfig = {
    Label = "mcquack.eblume.runner-cache-sweep";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackRunnerCacheSweep}" ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      # mise shims first: the script's `prek` resolves through them, like the runner agent.
      PATH = "/Users/erichblume/.local/share/mise/shims:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      HOME = "/Users/erichblume";
    };
    StartCalendarInterval = { Hour = 5; Minute = 30; };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.runner-cache-sweep.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.runner-cache-sweep.err.log";
  };

  # Prune boots the main runner out first and restores it via trap, because
  # `uv cache prune` also removes the per-script environments a live job uses
  # (eblume/blumeops#1065).
  launchd.user.agents."mcquack.eblume.runner-cache-prune".serviceConfig = {
    Label = "mcquack.eblume.runner-cache-prune";
    ProgramArguments = [ "${nixWait}" ] ++ [ "${mcquackRunnerCachePrune}" ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      PATH = "/Users/erichblume/.local/share/mise/shims:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      HOME = "/Users/erichblume";
      # uv's macOS default cache lives under ~/Library/Caches; pin the same
      # dir the runner jobs and the sweep use.
      UV_CACHE_DIR = "/Users/erichblume/.cache/uv";
    };
    StartCalendarInterval = { Day = 1; Hour = 3; Minute = 30; };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.runner-cache-prune.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.runner-cache-prune.err.log";
  };

  # forgejo (PR 8): most critical unit - with it unloaded the whole forge (API, git ssh
  # 2222, every forge-bound git op, every CI run) is down; caddy stays up (502s) and the
  # registry stays up. Binary stays the source build - no mirror lineage on nixpkgs
  # aarch64-darwin; revisit at the next upgrade. app.ini, work path and build stay
  # role-rendered (the gate covers the plist + load only). See provision.md §Forgejo.
  launchd.user.agents."mcquack.eblume.forgejo".serviceConfig = {
    Label = "mcquack.eblume.forgejo";
    ProgramArguments = [
      "/Users/erichblume/code/3rd/forgejo/forgejo"
      "-w"
      "/Users/erichblume/forgejo"
      "-c"
      "/Users/erichblume/forgejo/custom/conf/app.ini"
      "web"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.forgejo.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.forgejo.err.log";
  };

  # jellyfin (PR 9, part of eblume/blumeops#1291): first unit without the .eblume. label - the
  # in-place swap forbids renaming mcquack.jellyfin (logrotate globs, alloy tails and the
  # restart runbook key on it). The binary stays the DMG app at the role-maintained stable
  # symlink ~/opt/jellyfin-current, so a version bump is role-only and never touches this unit.
  # See provision.md §Jellyfin.
  launchd.user.agents."mcquack.jellyfin".serviceConfig = {
    Label = "mcquack.jellyfin";
    ProgramArguments = [
      "/Users/erichblume/opt/jellyfin-current/Jellyfin.app/Contents/MacOS/jellyfin"
      "--service"
      "--datadir"
      "/Users/erichblume/Library/Application Support/jellyfin"
      "--webdir"
      "/Users/erichblume/opt/jellyfin-current/Jellyfin.app/Contents/Resources/jellyfin-web"
    ];
    WorkingDirectory = "/Users/erichblume/Library/Application Support/jellyfin";
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.jellyfin.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.jellyfin.err.log";
  };

  # borgmatic (PR 11, part of eblume/blumeops#1291): all four backup LaunchAgents move
  # here at the role's labels and plist paths — each with its cron-style backup
  # window. The main agent backs up the archive tier (zk + Documents) and the
  # talos-data config, so it carries both --config args (config.yaml +
  # talos-data.yaml), key-for-key with the role's plist after the #1441 tier split;
  # the ops agent backs up the operational tier (03:00), photos the Immich library
  # (04:00), and verify-photos runs the weekly/2nd-of-month verification. The binary
  # stays the mise pipx `latest` symlink (borgmatic 2.1.7) — outside
  # /nix, so the unit stays in the #1225 safe class, the same zot/forgejo absolute-path
  # precedent as devpi's venv (verify-photos execs the role's verification script).
  # Config yamls, .pgpass, BorgBase key, k8s dump helpers and
  # the mise install stay role-rendered; only the plist + load move here. No
  # KeepAlive/RunAtLoad: calendar-triggered only — a failed run retries at the next
  # window, there is no supervisor. See provision.md §Borgmatic.
  launchd.user.agents."mcquack.eblume.borgmatic".serviceConfig = {
    Label = "mcquack.eblume.borgmatic";
    ProgramArguments = [
      "/Users/erichblume/.local/share/mise/installs/pipx-borgmatic/latest/bin/borgmatic"
      "--config"
      "/Users/erichblume/.config/borgmatic/config.yaml"
      "--config"
      "/Users/erichblume/.config/borgmatic/talos-data.yaml"
      "create"
    ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StartCalendarInterval = { Hour = 2; Minute = 0; };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic.err.log";
  };
  launchd.user.agents."mcquack.eblume.borgmatic-photos".serviceConfig = {
    Label = "mcquack.eblume.borgmatic-photos";
    ProgramArguments = [
      "/Users/erichblume/.local/share/mise/installs/pipx-borgmatic/latest/bin/borgmatic"
      "--config"
      "/Users/erichblume/.config/borgmatic/photos.yaml"
      "create"
    ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StartCalendarInterval = { Hour = 4; Minute = 0; };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-photos.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-photos.err.log";
  };

  # borgmatic-ops: the operational tier (forgejo, config, dumps, /Volumes/shower),
  # daily 03:00 — key-for-key with the role's borgmatic-ops.plist.j2.
  launchd.user.agents."mcquack.eblume.borgmatic-ops".serviceConfig = {
    Label = "mcquack.eblume.borgmatic-ops";
    ProgramArguments = [
      "/Users/erichblume/.local/share/mise/installs/pipx-borgmatic/latest/bin/borgmatic"
      "--config"
      "/Users/erichblume/.config/borgmatic/operational.yaml"
      "create"
      "prune"
      "compact"
    ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StartCalendarInterval = { Hour = 3; Minute = 0; };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-ops.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-ops.err.log";
  };

  # borgmatic-verify-photos: weekly (Tuesday) + 2nd-of-month verification, 06:00 —
  # key-for-key with the role's borgmatic-verify-photos.plist.j2. The program is
  # the pipx venv python (the same interpreter the create agents use, the
  # TCC-granted identity that reads /Volumes/photos), not the bash script itself:
  # launchd's responsible process must hold the Network Volumes grant, so the
  # python spawns the role's verification script as a subprocess that inherits it.
  launchd.user.agents."mcquack.eblume.borgmatic-verify-photos".serviceConfig = {
    Label = "mcquack.eblume.borgmatic-verify-photos";
    ProgramArguments = [
      "/Users/erichblume/.local/share/mise/installs/pipx-borgmatic/latest/borgmatic/bin/python"
      "-c"
      "import subprocess,sys; sys.exit(subprocess.run(['/bin/bash','/Users/erichblume/.local/bin/borgmatic-verify-photos']).returncode)"
    ];
    RunAtLoad = false;
    KeepAlive = false;
    EnvironmentVariables = {
      PATH = "/opt/homebrew/bin:/usr/bin:/bin";
    };
    StartCalendarInterval = [
      { Weekday = 2; Hour = 6; Minute = 0; }
      { Day = 2; Hour = 6; Minute = 0; }
    ];
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-verify-photos.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.borgmatic-verify-photos.err.log";
  };

  # devpi (PR 10, part of eblume/blumeops#1291): unit-in-nix, venv-stays-role-rendered — the
  # uv-managed venv at /Users/erichblume/devpi (devpi-server 6.20.3 / devpi-web 5.1.1) is the
  # zot/forgejo source-path precedent: binary outside /nix, so the unit stays in the #1225
  # safe class (binaries outside the store). The venv build and devpi-init seeding stay
  # role-owned; only the plist + load move here. See provision.md §Devpi.
  launchd.user.agents."mcquack.eblume.devpi".serviceConfig = {
    Label = "mcquack.eblume.devpi";
    ProgramArguments = [
      "/Users/erichblume/devpi/venv/bin/devpi-server"
      "--serverdir"
      "/Users/erichblume/devpi/server-dir"
      "--host"
      "127.0.0.1"
      "--port"
      "3141"
      "--outside-url"
      "https://pypi.ops.eblu.me"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      PATH = "/Users/erichblume/devpi/venv/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.devpi.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.devpi.err.log";
  };

  # alloy: the box's metrics flow (scrape + Loki push) and log tailing. The binary
  # stays the role's source-built CGO Mach-O (nixpkgs' grafana-alloy builds with the
  # netgo tag — pure-Go DNS, which breaks Tailscale MagicDNS — and is 1.16.0 vs the
  # box's v1.19.2, so a store flip would be a downgrade and a resolver regression);
  # outside /nix, the
  # devpi-venv precedent, so #1225-safe. The unit execs with no --server.http
  # flag, so the config's self-scrape (127.0.0.1:12345) and the /-/ready check
  # keep their default address. config.alloy, the storage dir, the textfile dir
  # and the tails stay role-rendered; the role's gate covers only plist + load.
  # Rollback per §Rolling back a service flip.
  launchd.user.agents."mcquack.eblume.alloy".serviceConfig = {
    Label = "mcquack.eblume.alloy";
    ProgramArguments = [
      "/Users/erichblume/.local/bin/alloy"
      "run"
      "/Users/erichblume/.config/grafana-alloy/config.alloy"
      "--storage.path=/Users/erichblume/.local/share/grafana-alloy"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.alloy.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.alloy.err.log";
  };

  # --- build runner daemons (eblume/blumeops#1357) ---
  # The `indri-build` label runner's daemons live in the *system* launchd
  # domain (launchd.daemons, /Library/LaunchDaemons), not per-user: the VM
  # must host the engine before anyone logs the build user in. Both run as
  # the unprivileged `indri-build` user (UserName); the pre-/nix boot guard
  # is the nixWaitSystem wrapper on argv0 (a store argv0 fails EX_CONFIG in
  # that window and launchd never retries it, eblume/blumeops#1225). On the
  # first-ever switch the home dirs are created in postActivation, after the
  # plists load, so each daemon's first RunAtLoad spawn fails on the missing
  # StandardOutPath dir and KeepAlive + ThrottleInterval retried it seconds
  # later - one-time, before registration anyway. With either unloaded,
  # `indri-build`-label jobs queue on forge - nothing else is affected.

  # colima: the build runner's container-engine host. The socket jobs use is
  # at ~indri-build/.colima/indri-build/docker.sock (the profile dir), owned
  # by indri-build - not world-reachable, not under /Users/Shared. With colima
  # down, every job that needs docker fails.
  launchd.daemons."mcquack.eblume.colima-build".serviceConfig = {
    Label = "mcquack.eblume.colima-build";
    ProgramArguments = [ "${nixWaitSystem}" ] ++ [ "${mcquackColimaBuild}" ];
    UserName = "indri-build";
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    # 300 s bounds a switch that stops a cold `colima start` mid-flight; the
    # sleep loop afterwards dies instantly.
    ExitTimeOut = 300;
    EnvironmentVariables = {
      HOME = "/Users/indri-build";
      # nixpkgs colima wraps itself with its lima and qemu bin dirs
      # prefixed into PATH, so only colima's bin dir, the docker CLI its
      # dependency check demands (see dockerClient), and the usual macOS/nix
      # dirs are needed here.
      PATH = "${colimaBuild}/bin:${dockerClient}/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
    };
    StandardOutPath = "/Users/indri-build/Library/Logs/mcquack.colima-build.out.log";
    StandardErrorPath = "/Users/indri-build/Library/Logs/mcquack.colima-build.err.log";
  };

  # forgejo-runner-build: the second runner daemon. The wrapper (not the
  # plist) waits for the colima socket - WaitForPaths is not expressible in
  # the pinned nix-darwin - so on a fresh boot with an empty VM disk (first
  # start takes minutes) the runner idles until colima exposes the socket:
  # correct, not a fault. With the unit unloaded, indri-build jobs queue on forge.
  launchd.daemons."mcquack.eblume.forgejo-runner-build".serviceConfig = {
    Label = "mcquack.eblume.forgejo-runner-build";
    ProgramArguments = [ "${nixWaitSystem}" ] ++ [ "${forgejoRunnerBuildWaiter}" ];
    WorkingDirectory = "/Users/indri-build/forgejo-runner";
    UserName = "indri-build";
    RunAtLoad = true;
    KeepAlive = true;
    # 60 s, chosen deliberately: this unit is in the *system* domain, where
    # (unlike the gui domain) launchd honors ExitTimeOut up to 3h, so the
    # 10800 that would mirror the erichblume runner's agent would make every
    # switch wait as long as the runner's job timeout to unload this unit.
    # AbandonProcessGroup is what matters: without it a stop kills the
    # process group and takes a detached darwin-rebuild mid-activation.
    ExitTimeOut = 60;
    AbandonProcessGroup = true;
    EnvironmentVariables = {
      # mise shims first (job steps resolve tools via indri-build's own mise
      # config, config-build-user.toml), then the nix docker CLI (see
      # dockerClient) for jobs that talk to the colima socket. The
      # nix default profile last: host-mode jobs reach `nix` for multi-user
      # daemon builds as the untrusted indri-build user (eblume/blumeops#1358),
      # without shadowing anything above it.
      PATH = "/Users/indri-build/.local/share/mise/shims:${dockerClient}/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
      HOME = "/Users/indri-build";
    };
    StandardOutPath = "/Users/indri-build/Library/Logs/mcquack.forgejo-runner-build.out.log";
    StandardErrorPath = "/Users/indri-build/Library/Logs/mcquack.forgejo-runner-build.err.log";
  };

  # macos-power-metrics: the first nix-owned daemon outside the indri-build
  # pair. Runs as root (no UserName) — powermetrics needs it — writing
  # macos_power.prom into alloy's node_exporter textfile dir every 30 s. The
  # script stays role-rendered at /usr/local/bin (outside /nix), so there is no
  # post-reboot gap: nix-darwin activation writes the plist as a real file into
  # /Library/LaunchDaemons and launchd re-registers it at every boot (a #1225
  # EX_CONFIG-never-retried failure needs a store argv0, this is not one). The
  # one lost-samples window is the rollback drill: a rolled-back generation stops
  # declaring the daemon, and the system phase unloads + deletes it until the
  # gated role re-run rewrites and loads the ansible plist.
  launchd.daemons."mcquack.eblume.macos-power-metrics".serviceConfig = {
    Label = "mcquack.eblume.macos-power-metrics";
    ProgramArguments = [ "/usr/local/bin/macos-power-metrics" ];
    RunAtLoad = true;
    StartInterval = 30;
    StandardOutPath = "/var/log/mcquack.macos-power-metrics.out.log";
    StandardErrorPath = "/var/log/mcquack.macos-power-metrics.err.log";
  };
}
