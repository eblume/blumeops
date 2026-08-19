# Shared plumbing for ringtail's hephd spokes. Two spokes run on this host —
# same pinned heph version, same hub, different identities and token stores:
#   - agent-heph-*  (agent-heph-spoke.nix): logs in as the revocable
#     `heph-agents` user; token lives in the agents 1Password vault.
#   - eblume-heph-* (heph-eblume.nix): Erich's own spoke for interactive
#     sessions; token cached as a 0600 file in his home.
# Plain import (`import ./heph-common.nix { inherit pkgs lib; }`), not a module.
{ pkgs, lib }:
rec {
  hephTag = "v1.8.1"; # cargo-installed at this tag by the per-user install oneshots
  rustChannel = "stable"; # mise-resolved toolchain — nixpkgs rustc lags heph's floor
  hubUrl = "http://indri.tail8d86e.ts.net:8787"; # spoke sync is HTTP-only
  issuer = "https://authentik.ops.eblu.me/application/o/heph/";
  # Anonymous HTTPS clone for the build (public repo) — no SSH host key / bot
  # key, matching the ansible heph role + hephd self-update.
  repoHttps = "https://forge.eblu.me/eblume/hephaestus.git";
  # The hub's single owner id (Erich's heph data). Every spoke ADOPTS it so all
  # spokes operate on the *same* nodes; only the login identity varies per
  # spoke. Not a secret (it appears in HLCs); nix can't read the vault at eval
  # time anyway.
  ownerId = "01KT4MYCG6Q45N3MJ665V53AMM";

  # System libraries `cargo install heph hephd` needs to build (dbus for the
  # compiled-in keyring backend, even where a spoke uses another token store).
  buildDeps = with pkgs; [ dbus openssl sqlite zlib ];

  # Extra libraries the `heph-quickadd` GUI needs — build (pkg-config) *and*
  # run (dlopen). eframe/winit resolve most of these lazily at runtime, so the
  # binary's DT_NEEDED list understates them; see `guiLibPath` below.
  guiDeps = with pkgs; [
    libxkbcommon
    wayland
    libGL
    libglvnd
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    fontconfig
    freetype
  ];

  # LD_LIBRARY_PATH for a cargo-built heph GUI binary. The nix-ld interpreter
  # handles DT_NEEDED, but glutin/winit `dlopen` libEGL/libGL/libxkbcommon by
  # soname at runtime, and /run/opengl-driver/lib is where NixOS puts the
  # NVIDIA/mesa ICDs that libglvnd dispatches to.
  guiLibPath = "/run/opengl-driver/lib:${lib.makeLibraryPath guiDeps}";

  # What a desktop spoke installs: the daemon and CLI plus the two interactive
  # surfaces. The agent's headless spoke takes the mkInstallUnits default.
  desktopBins = [ "heph" "hephd" "heph-tui" "heph-quickadd" ];

  # Only the GUI binary needs the graphics stack, and LD_LIBRARY_PATH is
  # inherited by children — heph-tui shells out to nvim, which must not get it.
  guiLibExport = ''
    export LD_LIBRARY_PATH="${guiLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  # Shims that put the cargo-installed heph binaries on the session PATH.
  #
  # `cargo install` writes to ~/.cargo/bin, which nothing here adds to a session
  # PATH: sway is started by greetd and passes on only the nix profile
  # directories, so a terminal opened from the desktop cannot see `heph` or
  # `heph-tui` at all (fish's config doesn't add it either). These shims live in
  # the user's home-manager profile — /etc/profiles/per-user/<user>/bin, which
  # *is* on that PATH — and exec the real binary.
  mkShims = { home, bins }:
    pkgs.buildEnv {
      name = "heph-shims";
      paths = map
        (b: pkgs.writeShellScriptBin b (
          (lib.optionalString (b == "heph-quickadd") guiLibExport)
          + ''exec ${home}/.cargo/bin/${b} "$@"''
        ))
        bins;
    };

  # What a compositor keybinding runs to raise the quick-capture popover.
  #
  # `popover` is the one-shot mode: one process per capture, exiting when the
  # popover is saved, escaped, or clicked away. The warm-agent mode heph-quickadd
  # uses on macOS cannot work under Wayland — a window there cannot be hidden
  # (winit's `set_visible` is a no-op) and there is no X11-style global key grab,
  # so a "hidden" agent would both sit on screen and be unsummonable. Sway owns
  # the hotkey instead; see the `Mod1+apostrophe` binding in configuration.nix.
  mkQuickaddLauncher = { home }:
    pkgs.writeShellScriptBin "heph-quickadd-popover" (guiLibExport + ''
      exec ${home}/.cargo/bin/heph-quickadd popover "$@"
    '');

  # Install units (system scope) for one user's heph toolchain:
  #   <prefix>-install (oneshot)  — idempotent `cargo install` at hephTag via a
  #     mise-resolved rust toolchain; version-checks so re-runs are no-ops.
  #   <prefix>-install (timer)    — fires the install shortly after boot/switch,
  #     keeping the (first-run ~tens of minutes) compile OFF the activation path.
  #
  # `bins` selects which workspace binaries to install. Headless spokes (the
  # agent) want just the daemon + CLI; a desktop spoke also wants the TUI and
  # the quick-capture GUI.
  mkInstallUnits = { prefix, user, group, home, who, bins ? [ "heph" "hephd" ] }:
    let
      cargoBin = "${home}/.cargo/bin";
      install = pkgs.writeShellScript "${prefix}-install" ''
        set -eu
        export HOME=${home}
        export PATH="${lib.makeBinPath [ pkgs.mise pkgs.gcc pkgs.pkg-config pkgs.binutils pkgs.gnumake pkgs.coreutils pkgs.gitMinimal pkgs.gawk ]}:$PATH"
        export CC=gcc
        export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev (buildDeps ++ guiDeps))}"
        target="${lib.removePrefix "v" hephTag}"
        have="$(${cargoBin}/hephd --version 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' || true)"
        # Version-gate on hephd, but also require every requested binary to be
        # present: adding a bin to `bins` must not be skipped just because the
        # daemon is already at the pinned tag.
        complete=1
        for b in ${lib.concatStringsSep " " bins}; do
          [ -x "${cargoBin}/$b" ] || complete=0
        done
        if [ "$have" = "$target" ] && [ "$complete" = 1 ]; then
          echo "heph $target already installed (${lib.concatStringsSep ", " bins})"; exit 0
        fi
        echo "installing heph ${hephTag} (rust@${rustChannel} via mise)…"
        # Retry: a Type=oneshot won't auto-restart, and the mise toolchain
        # download / cargo fetch can flake transiently on a cold cache.
        for attempt in 1 2 3; do
          if mise x rust@${rustChannel} -- cargo install --locked --force \
              --git ${repoHttps} --tag ${hephTag} ${lib.concatStringsSep " " bins}; then
            exit 0
          fi
          echo "heph install attempt $attempt failed; retrying in 15s…" >&2
          sleep 15
        done
        echo "heph install failed after 3 attempts" >&2
        exit 1
      '';
    in
    {
      services."${prefix}-install" = {
        description = "Install heph+hephd for ${who} (mise rust + cargo install)";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = user;
          Group = group;
          ExecStart = install;
          # First build compiles the whole workspace from a cold cargo cache.
          TimeoutStartSec = "45min";
        };
      };
      timers."${prefix}-install" = {
        description = "Trigger ${prefix}-install off the activation path";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          Persistent = true;
        };
      };
    };

  # Full SYSTEM-scope quartet: the install units above plus the spoke service
  # (ConditionPathExists on the hephd binary, so pre-install it is cleanly
  # *skipped*, not failed) and a path unit that starts the spoke the moment the
  # install produces the binary. The caller supplies the spoke launcher
  # (`spokeExec`) since the token store and PATH needs differ per spoke.
  #
  # System scope means NO XDG_RUNTIME_DIR: hephd binds its fallback socket at
  # ~/.local/share/heph/hephd.sock. That fits the agent (its sessions run inside
  # the equally env-less workspace service, so CLI and daemon agree) but NOT an
  # interactive user, whose shells resolve /run/user/<uid>/heph/hephd.sock — an
  # interactive user's spoke belongs in the systemd USER manager instead (see
  # heph-eblume.nix).
  mkSpokeStack = { prefix, user, group, home, spokeExec, who }:
    let
      cargoBin = "${home}/.cargo/bin";
      installUnits = mkInstallUnits { inherit prefix user group home who; };
    in
    {
      services = installUnits.services // {
        "${prefix}-spoke" = {
          description = "heph spoke for ${who} (hephd synced to the indri hub)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          startLimitIntervalSec = 0;
          unitConfig.ConditionPathExists = "${cargoBin}/hephd";
          serviceConfig = {
            User = user;
            Group = group;
            ExecStart = spokeExec;
            Restart = "always";
            RestartSec = 10;
            StandardOutput = "journal";
            StandardError = "journal";
            NoNewPrivileges = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
          };
        };
      };
      timers = installUnits.timers;
      paths."${prefix}-spoke" = {
        description = "Start ${who}'s heph spoke once hephd is installed";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathExists = "${cargoBin}/hephd";
      };
    };
}
