{ config, lib, pkgs, ... }:
let
  mcquackLogrotate = pkgs.writeScript "mcquack-logrotate" (builtins.readFile ./mcquack-logrotate.sh);
  # The four *-metrics collectors feed alloy's node_exporter textfile dir;
  # PR 4 of the series moved their units and scripts here.
  mcquackBorgmaticMetrics = pkgs.writeScript "mcquack-borgmatic-metrics" (builtins.readFile ./mcquack-borgmatic-metrics.sh);
  mcquackForgejoMetrics = pkgs.writeScript "mcquack-forgejo-metrics" (builtins.readFile ./mcquack-forgejo-metrics.sh);
  mcquackJellyfinMetrics = pkgs.writeScript "mcquack-jellyfin-metrics" (builtins.readFile ./mcquack-jellyfin-metrics.sh);
  mcquackZotMetrics = pkgs.writeScript "mcquack-zot-metrics" (builtins.readFile ./mcquack-zot-metrics.sh);
  # Where activation links the generation-owned mise config; mise follows
  # the symlink for reads and writes.
  miseConfigHome = "${config.system.primaryUserHome}/.config/mise/config.toml";

  # Caddy the mcquack.eblume.caddy unit runs: nixpkgs caddy with the two
  # plugins the Caddyfile actually uses (gandi = ACME DNS-01, l4 = the
  # TCP routes). It must be in systemPackages: the
  # role-rendered wrapper execs it through the system profile's sw/bin,
  # and a raw store path in that wrapper is not GC-rooted. The vendor
  # hash is the TOFU'd output of the same derivation at the pinned
  # nixpkgs rev (the go mod vendor output is platform-independent);
  # indri's CI confirms it.
  caddyWithPlugins = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/gandi@v1.1.0"
      "github.com/mholt/caddy-l4@v0.1.2"
    ];
    hash = "sha256-aEoxvsD7aYwZdORc3iLO7TQ9vzj3bpKWqJ8eIBD/bzY=";
  };
in
{
  # Explicit target platform: indri is an M1 Mac mini, and pinning it
  # keeps the flake evaluable (and checkable) from off-box hosts.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # The caddy unit's binary, rooted in the generation's closure (see
  # caddyWithPlugins above). eblume/blumeops#1275.
  environment.systemPackages = [ caddyWithPlugins ];

  # Determinate Nix owns the daemon, the /nix store, and the nix config
  # (/etc/nix/nix.custom.conf). nix-darwin aborts activation if
  # /usr/local/bin/determinate-nixd exists unless this is false, so this is a
  # hard requirement, not a preference. See [[indri]] §Nix.
  nix.enable = false;

  system.primaryUser = "erichblume";
  system.stateVersion = 6;

  programs.bash.enable = true;
  programs.fish.enable = true;

  # zsh management is off: the login shell is Homebrew's fish, and the
  # nix-darwin etc check aborts on the stock /etc/zshrc and /etc/zprofile
  # (their hashes are not in its known list). See [[provision]].
  programs.zsh.enable = false;

  # Rule: nothing that must work before the Nix Store mounts may live in
  # /etc/static. Every environment.etc entry is a symlink into the store,
  # dangling until Determinate's daemon mounts the volume (tens of seconds
  # after boot). Two consumers do not tolerate a dangling link:

  # - mDNSResponder's /etc/resolver scan skips one and never rescans, so
  #   /etc/resolver/ts.net (tailnet MagicDNS, nameserver 100.100.100.100)
  #   is a real file the indri play writes before the switch (its
  #   tailnet-dns task), not declared here - and not via services.tailscale,
  #   which would emit a second tailscaled daemon beside the live Homebrew
  #   root daemon.
  #
  # - sshd's `Include /etc/ssh/sshd_config.d/*` exits 1 on a missing file,
  #   refusing every ssh until the mount. So no sshd drop-in may be a
  #   nix-darwin /etc/static link:
  services.openssh.hostKeys = [];   # drops 099-host-keys.conf and its keygen script
  environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".enable = false;
  environment.etc."ssh/sshd_config.d/101-authorized-keys.conf".enable = false;

  # /etc/shells: the retired 25.05 generation had replaced Apple's stock
  # file with its own symlink, and the first 26.05 generation (which
  # declares no environment.shells) removed it, leaving no /etc/shells at
  # all. Restore the stock list plus the login shell actually in use.
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

  # Never sleep. indri is a server whose only sleep guard was Amphetamine,
  # a GUI app; on 2026-09-16 it segfaulted after 280 h and `pmset sleep 1`
  # put the box to sleep 4 minutes later (forge, registry and every
  # *.ops.eblu.me route dark until someone touched it). This is the
  # declarative `pmset -a sleep 0`; Amphetamine stays as the second layer.
  # See [[indri]] §Maintenance Notes.
  power.sleep.computer = "never";

  # --- mise toolchain (declarative) ---
  # indri's global mise config: the go baseline the source builds use, the
  # CI host tools the forgejo runner needs, and the go.set_goroot setting the
  # GOTOOLCHAIN=auto builds depend on. This used to be written imperatively
  # by the indri play (`mise use --global`, `mise settings set`); the play
  # now only keeps the Homebrew mise install + version floor. A pin change
  # is a flake PR plus `mise run provision-indri -- --tags rebuild`; a
  # newly-pinned version is installed on first shim use (mise auto_install)
  # or by `mise install`.
  #
  # environment.etc lands it at /etc/static/mise/config.toml; the
  # postActivation fragment below symlinks it as
  # ${config.system.primaryUserHome}/.config/mise/config.toml. The file is
  # generation-owned and read-only in practice: change pins here, not with
  # `mise use --global` / `mise settings set`. The fragment runs under
  # `set -e` as root; every path must end in a success, so it cannot fail
  # the switch. The target store path differs per generation, so
  # `darwin-rebuild --rollback` re-links the previous generation's config
  # automatically.
  environment.etc."mise/config.toml".text = ''
    [settings.go]
    # GOROOT export stays off: an exported GOROOT breaks Go's
    # GOTOOLCHAIN=auto switching (the auto-switched driver resolves
    # `compile` from the pinned GOROOT). See [[upgrade-forgejo]] §Go
    # toolchain.
    set_goroot = false

    [tools]
    # The global go baseline for the forgejo/zot source builds, plus the
    # host CI tools the forgejo runner's jobs resolve via the shims.
    # Every pin mirrors one that lives elsewhere (prek.toml,
    # service-versions.yaml, the dagger CLI pin); this file is the single
    # source of truth on indri.
    go = "1.26.7"
    dagger = "0.21.9"
    prek = "0.4.14"
    flyctl = "0.4.87"
    argocd = "3.3.12"
    actionlint = "1.7.12"
    stylua = "2.4.1"
    shellcheck = "0.11.0"
    # uv is resolved through the shim by the devpi role (venv build) and by
    # the indri-label CI jobs (`uv run --script`); without a pin the shim
    # falls through to Homebrew's uv, so the version would drift silently.
    uv = "0.11.7"
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
  '';

  # --- launchd label convention for nix-managed services ---
  # Every nix-managed user agent sets serviceConfig.Label =
  # "mcquack.eblume.<svc>". Activation diffs the plist and, on change,
  # unloads, replaces and reloads it (one restart, never dual-loaded). The
  # label is what logrotate's globs and alloy's log tails key on, so it
  # must not change.
  #
  # Rollback when a generation breaks a service's plist is in a fixed
  # order: darwin-rebuild --rollback first (nix-darwin unloads agents the
  # target generation does not declare - the service is down), then run the
  # service's ansible role with its skip gate flipped, e.g. `mise run
  # provision-indri -- --tags logrotate -e logrotate_ansible_managed=true`.
  # Never ansible first. See [[provision]] §Rolling back a service flip.

  # logrotate: first service moved to nix-darwin (PR 2 of the series). The
  # Label fixes both the launchd identity and the plist filename, so the
  # generation and the (skipped-by-default) ansible role own one path,
  # ~/Library/LaunchAgents/mcquack.eblume.logrotate.plist, and swap in
  # place; the role's only job left is the rollback re-write. The log
  # paths stay the ones alloy tails and the script itself rotates.
  launchd.user.agents."mcquack.eblume.logrotate".serviceConfig = {
    Label = "mcquack.eblume.logrotate";
    ProgramArguments = [ "${mcquackLogrotate}" ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.err.log";
  };

  # metrics collectors: the four *-metrics agents (borgmatic, forgejo,
  # jellyfin, zot), PR 4 of the series. Same labels and plist paths the
  # ansible roles used, so each plist swaps in place, one reload, never
  # dual-loaded. Same .prom files in alloy's textfile dir and the same
  # /opt/homebrew/var/log logs, so alloy and the TextfileStale alert are
  # unaffected. The API key files (~/.forgejo-api-key, ~/.jellyfin-api-key)
  # stay controller-side op placement: the roles' key-file tasks are not
  # gated (they still write the same paths a rollback re-write keeps).
  launchd.user.agents."mcquack.eblume.borgmatic-metrics".serviceConfig = {
    Label = "mcquack.eblume.borgmatic-metrics";
    ProgramArguments = [ "${mcquackBorgmaticMetrics}" ];
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
    ProgramArguments = [ "${mcquackForgejoMetrics}" ];
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
    ProgramArguments = [ "${mcquackJellyfinMetrics}" ];
    StartInterval = 60;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/jellyfin-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/jellyfin-metrics.err.log";
  };

  launchd.user.agents."mcquack.eblume.zot-metrics".serviceConfig = {
    Label = "mcquack.eblume.zot-metrics";
    ProgramArguments = [ "${mcquackZotMetrics}" ];
    StartInterval = 60;
    RunAtLoad = true;
    StandardOutPath = "/opt/homebrew/var/log/mcquack.zot-metrics.out.log";
    StandardErrorPath = "/opt/homebrew/var/log/mcquack.zot-metrics.err.log";
  };

  # zot registry: first real daemon the series moves (PR 5). It is a
  # long-running process, not a collector: with the unit unloaded the
  # registry — and every pull/push behind it — is down until something
  # reloads the unit. The unit stays a user LaunchAgent at the same
  # label and plist path the ansible role used (logrotate's globs,
  # alloy's log tails and services-check key on them). The binary
  # stays the source build in ~/code/3rd/zot (not yet nix-managed),
  # and config.json / oidc-credentials.json stay role-rendered: the
  # role's gate covers only the plist + load tasks.
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

  # caddy: the widest daemon the series moves (PR 6). It fronts every
  # *.ops.eblu.me endpoint and the L4 routes (forge ssh 2222, postgres
  # 5433/5434, the sifaka exporter ports): with the unit unloaded the
  # forge API/ssh, the registry, every image pull from the cluster and
  # indri's own runner reaching forge.ops.eblu.me - so no CI runs land
  # either - go down until something reloads the unit. The unit stays a
  # user LaunchAgent at the same label and plist path the ansible role
  # used (logrotate's globs, alloy's log tails and services-check key on
  # them). The binary is caddyWithPlugins from systemPackages, and the
  # role-rendered wrapper execs it through the system profile's sw/bin
  # (see the wrapper template), so it follows every switch and
  # --rollback. ProgramArguments[0] stays the on-disk wrapper, not a
  # store path: a store path there dies EX_CONFIG in the pre-/nix boot
  # window (eblume/blumeops#1225), whereas bash-at-boot just fails the
  # exec (127) and KeepAlive respawns it until /nix mounts. The
  # Caddyfile, wrapper and Gandi token file stay role-rendered: the
  # role's gate covers only the plist + load tasks.
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

  # forgejo-runner: the daemon that executes every `indri`-label CI job (PR 7),
  # and the first unit the series moves whose binary comes from nixpkgs
  # (13.1.0, the rev the flake's nixpkgs input pins for everything else).
  # Upstream ships no darwin release binaries, which is why this was the
  # source build in ~/code/3rd/forgejo-runner; that checkout stays on disk
  # only as the ansible rollback re-write's target - the role no longer
  # builds or checks it. config.yaml (the runner token), the runner home and
  # the cache prune/sweep agents stay role-rendered: the role's gate
  # (forgejo_runner_ansible_managed) covers only the plist + load tasks.
  # With the unit unloaded, indri-label jobs queue on forge; forge, the
  # registry and every *.ops.eblu.me endpoint stay up (unlike caddy).
  launchd.user.agents."mcquack.eblume.forgejo-runner".serviceConfig = {
    Label = "mcquack.eblume.forgejo-runner";
    ProgramArguments = [
      "${pkgs.forgejo-runner}/bin/forgejo-runner"
      "daemon"
      "--config"
      "/Users/erichblume/forgejo-runner/config.yaml"
    ];
    WorkingDirectory = "/Users/erichblume/forgejo-runner";
    RunAtLoad = true;
    KeepAlive = true;
    # A plist-changing switch rewrites this file, so launchd reloads the
    # agent and SIGKILLs the in-flight forge job within ~60 s — launchd
    # clamps ExitTimeOut to 60 s in the per-user gui domain (measured on
    # macOS 26: the plist says 10800, `launchctl print` reports 60), so
    # this key is not a real drain window and is kept only to document
    # intent and mirror the role's rollback re-write. AbandonProcessGroup
    # is what loads and matters: without it launchd kills the agent's
    # process group on stop, taking the detached darwin-rebuild (nohup,
    # same group) down mid-activation. eblume/blumeops#1266.
    ExitTimeOut = 10800;
    AbandonProcessGroup = true;
    EnvironmentVariables = {
      # mise shims first: host-mode jobs use indri's mise toolchain (node,
      # uv, yq, jq, prek, dagger, ...); the nix default profile last so the
      # flake check finds `nix` without shadowing anything above it.
      PATH = "/Users/erichblume/.local/share/mise/shims:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin";
      HOME = "/Users/erichblume";
    };
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.forgejo-runner.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.forgejo-runner.err.log";
  };

  # forgejo: the last unit the series moves (PR 8), and the most critical
  # service: with the unit unloaded the whole forge is down - the forge
  # API, the built-in git ssh (2222), every forge-bound git op from a
  # talos session and every CI run; caddy stays up (502s, not connection
  # failures) and the registry stays up (zot is a separate unit). The binary stays the source build in
  # ~/code/3rd/forgejo - the mirror lineage nixpkgs cannot offer on
  # aarch64-darwin; revisit the lineage at the next forgejo upgrade. The
  # app.ini, the work path and the version build stay role-rendered: the
  # role's gate (forgejo_ansible_managed) covers only the plist + load
  # tasks.
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
}
