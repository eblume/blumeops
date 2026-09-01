# Shared plumbing for ringtail's two hephd spokes (agent-heph-spoke.nix,
# heph-eblume.nix): same heph pin and hub, different identities and token
# stores. Plain import (`import ./heph-common.nix { inherit pkgs lib; }`),
# not a module.
{ pkgs, lib }:
rec {
  hephTag = "v1.10.0";
  rustChannel = "stable"; # mise-resolved — nixpkgs rustc lags heph's floor
  hubUrl = "http://indri.tail8d86e.ts.net:8787";
  issuer = "https://authentik.ops.eblu.me/application/o/heph/";
  # HTTPS clone: the build (public repo) needs no SSH key.
  repoHttps = "https://forge.eblu.me/eblume/hephaestus.git";
  # Adopted by every spoke so all spokes operate on the same nodes; only the
  # login identity varies. Not a secret (it appears in HLCs).
  ownerId = "01KT4MYCG6Q45N3MJ665V53AMM";

  # Build deps for `cargo install heph hephd` (dbus for the compiled-in keyring backend).
  buildDeps = with pkgs; [ dbus openssl sqlite zlib ];

  # heph-quickadd GUI deps — needed at build (pkg-config) and at runtime (dlopen).
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

  # GUI LD_LIBRARY_PATH: the dlopened libs plus the /run/opengl-driver GL ICDs.
  guiLibPath = "/run/opengl-driver/lib:${lib.makeLibraryPath guiDeps}";

  # Desktop-spoke binaries; headless spokes use the mkInstallUnits default.
  desktopBins = [ "heph" "hephd" "heph-tui" "heph-quickadd" ];

  # GUI-only graphics stack — children inherit LD_LIBRARY_PATH, so the
  # heph-tui shims must not use it (heph-tui shells out to nvim).
  guiLibExport = ''
    export LD_LIBRARY_PATH="${guiLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  # Shims that put the cargo-installed binaries (~/.cargo/bin, off the session
  # PATH) on the session PATH via the home-manager profile.
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

  # Raises the quick-capture popover; one process per capture, since Wayland
  # cannot hide a window (no persistent agent possible).
  mkQuickaddLauncher = { home }:
    pkgs.writeShellScriptBin "heph-quickadd-popover" (guiLibExport + ''
      exec ${home}/.cargo/bin/heph-quickadd popover "$@"
    '');

  # <prefix>-install oneshot + timer: `cargo install`s `bins` at hephTag via a
  # mise-resolved rust toolchain, off the activation path; the version + bin-set
  # check makes re-runs no-ops.
  #
  # `restartSpoke`: one shell command (wrap a list in `{ …; }`) run
  # best-effort after a successful install, so the spoke picks up the new
  # binary. `asRoot`: run the oneshot as root, doing the user-owned work via
  # runuser — needed to restart a system-scope spoke.
  mkInstallUnits = { prefix, user, group, home, who, bins ? [ "heph" "hephd" ], asRoot ? false, restartSpoke ? "" }:
    let
      cargoBin = "${home}/.cargo/bin";
      # runuser keeps the environment, so mise/cargo run in the user's state.
      runAsUser = lib.optionalString asRoot "runuser -u ${user} -- ";
      # Indented-string callers end with a newline that would break the splice.
      restartCmd = lib.removeSuffix "\n" restartSpoke;
      install = pkgs.writeShellScript "${prefix}-install" ''
        set -eu
        export HOME=${home}
        export PATH="${lib.makeBinPath [ pkgs.mise pkgs.gcc pkgs.pkg-config pkgs.binutils pkgs.gnumake pkgs.coreutils pkgs.gitMinimal pkgs.gawk pkgs.systemd pkgs.util-linux ]}:$PATH"
        export CC=gcc
        export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev (buildDeps ++ guiDeps))}"
        target="${lib.removePrefix "v" hephTag}"
        have="$(${runAsUser}${cargoBin}/hephd --version 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' || true)"
        # Also require every bin present: adding one to `bins` must install it.
        complete=1
        for b in ${lib.concatStringsSep " " bins}; do
          [ -x "${cargoBin}/$b" ] || complete=0
        done
        if [ "$have" = "$target" ] && [ "$complete" = 1 ]; then
          echo "heph $target already installed (${lib.concatStringsSep ", " bins})"; exit 0
        fi
        echo "installing heph ${hephTag} (rust@${rustChannel} via mise)…"
        # Oneshots do not auto-retry; a cold mise/cargo fetch can flake.
        for attempt in 1 2 3; do
          if ${runAsUser}mise x rust@${rustChannel} -- cargo install --locked --force \
              --git ${repoHttps} --tag ${hephTag} ${lib.concatStringsSep " " bins}; then
            ${lib.optionalString (restartSpoke != "") ''
              # Best-effort: a failed restart must not fail the install.
              if ! ${restartCmd}; then
                echo "warning: spoke restart not completed; the daemon keeps the old binary until it is restarted manually" >&2
              fi
            ''}
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
          ExecStart = install;
          # Cold-cache first build takes tens of minutes.
          TimeoutStartSec = "45min";
        } // lib.optionalAttrs (!asRoot) {
          User = user;
          Group = group;
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

  # System-scope quartet: the install units plus the spoke service and a path
  # unit that starts it once hephd exists; ConditionPathExists keeps the
  # pre-install state a clean skip, not a failure.
  #
  # System scope means no XDG_RUNTIME_DIR, so hephd binds the
  # ~/.local/share/heph fallback socket — right for env-less services, wrong
  # for interactive users (their spoke belongs in the USER manager;
  # heph-eblume.nix).
  mkSpokeStack = { prefix, user, group, home, spokeExec, who }:
    let
      cargoBin = "${home}/.cargo/bin";
      installUnits = mkInstallUnits {
        inherit prefix user group home who;
        # Root so the oneshot can restart the system-scope spoke.
        asRoot = true;
        restartSpoke = "systemctl try-restart ${prefix}-spoke.service";
      };
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
