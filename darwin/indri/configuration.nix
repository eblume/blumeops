{ config, lib, pkgs, inputs, ... }:
let
  mcquackLogrotate = pkgs.writeScript "mcquack-logrotate" (builtins.readFile ./mcquack-logrotate.sh);
  # The four *-metrics collectors feeding alloy's node_exporter textfile dir (PR 4 moved them here).
  mcquackBorgmaticMetrics = pkgs.writeScript "mcquack-borgmatic-metrics" (builtins.readFile ./mcquack-borgmatic-metrics.sh);
  mcquackForgejoMetrics = pkgs.writeScript "mcquack-forgejo-metrics" (builtins.readFile ./mcquack-forgejo-metrics.sh);
  mcquackJellyfinMetrics = pkgs.writeScript "mcquack-jellyfin-metrics" (builtins.readFile ./mcquack-jellyfin-metrics.sh);
  mcquackZotMetrics = pkgs.writeScript "mcquack-zot-metrics" (builtins.readFile ./mcquack-zot-metrics.sh);
  sifakaMounter = pkgs.writeScript "mount-sifaka" (builtins.readFile ./mount-sifaka.sh);
  # The build runner's colima engine host daemon (eblume/blumeops#1357):
  # colima with lima and qemu wrapped into its PATH by the colima flake's
  # packages.default. Not in nixpkgs; pinned as a flake input (see flake.nix).
  mcquackColimaBuild = pkgs.writeScript "mcquack-colima-build" (builtins.readFile ./mcquack-colima-build.sh);
  # The colima package the colima-build daemon runs: the colima flake input's
  # packages.default (colima + lima + qemu, see flake.nix).
  colimaBuild = inputs.colima.packages."aarch64-darwin".default;
  # The runner daemon's waiter: the pinned nix-darwin has no WaitForPaths
  # option, so the wait lives here. It idles until the role renders the runner
  # config (a human registers the runner first, so it is absent until then)
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

  # nix-darwin /etc entries are store symlinks dangling until /nix mounts, so nothing
  # pre-boot-critical may be one (mDNSResponder's /etc/resolver, sshd's drop-ins).
  # See provision.md §First switch.
  services.openssh.hostKeys = [];   # drops 099-host-keys.conf and its keygen script
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
    flyctl = "0.4.87"
    argocd = "3.3.12"
    actionlint = "1.7.12"
    stylua = "2.4.1"
    shellcheck = "0.11.0"
    # Pinned: devpi's venv + CI resolve uv via the shim, and without a pin it
    # falls through to Homebrew's uv and drifts silently.
    uv = "0.11.7"
  '';

  # The build runner user's own global mise config (eblume/blumeops#1357):
  # identical [tools] pins to the erichblume config above minus [settings.go]
  # (GOROOT handling is erichblume-only, for the forgejo/zot source builds).
  # The postActivation fragment links it into ~indri-build/.config/mise;
  # --rollback re-links the previous generation's.
  environment.etc."mise/config-build-user.toml".text = ''
    [tools]
    # CI host tools the build runner's job steps resolve via shims; same
    # pins as the erichblume global config, the single source of truth.
    go = "1.26.7"
    dagger = "0.21.9"
    prek = "0.4.14"
    flyctl = "0.4.87"
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
    u=$(id -u indri-build 2> /dev/null) || u=""
    if [[ -n "$u" && "$u" -ne 503 ]]; then
      printf >&2 'error: indri-build exists with uid %s, expected 503 - update the pair in darwin/indri/configuration.nix\n' "$u"
      exit 1
    fi
    if [[ -z "$u" ]] && dscl . -list /Users UniqueID 2> /dev/null | grep -qw 503; then
      printf >&2 'error: uid 503 is already taken on indri - update the pair in darwin/indri/configuration.nix\n'
      exit 1
    fi
    g=$(dscl . -read /Groups/indri-build PrimaryGroupID 2> /dev/null | sed 's/^PrimaryGroupID: //')
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
      # a planted symlink.
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

  # forgejo-runner (PR 7): executes every `indri`-label CI job; first nixpkgs-sourced
  # binary (upstream ships no darwin release). Unloaded = indri-label jobs queue on
  # forge; everything else stays up. config.yaml, home and cache agents stay
  # role-rendered (the gate covers the plist + load only). See provision.md §Forgejo runner.
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
      # The colima flake's packages.default wraps colima with its lima and
      # qemu bin dirs prefixed into PATH itself, so only colima's bin dir
      # (plus the usual macOS/nix dirs) is needed here.
      PATH = "${colimaBuild}/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
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
      # config, config-build-user.toml). The colima flake ships no docker
      # client: jobs get the docker CLI from Homebrew (/opt/homebrew/bin).
      PATH = "/Users/indri-build/.local/share/mise/shims:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
      HOME = "/Users/indri-build";
    };
    StandardOutPath = "/Users/indri-build/Library/Logs/mcquack.forgejo-runner-build.out.log";
    StandardErrorPath = "/Users/indri-build/Library/Logs/mcquack.forgejo-runner-build.err.log";
  };
}
