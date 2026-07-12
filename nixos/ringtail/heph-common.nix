# Shared plumbing for ringtail's hephd spokes. Two spokes run on this host —
# same pinned heph version, same hub, different identities and token stores:
#   - agent-heph-*  (agent-workspaces.nix): logs in as the revocable
#     `heph-agents` user; token lives in the agents 1Password vault.
#   - eblume-heph-* (heph-eblume.nix): Erich's own spoke for interactive
#     sessions; token cached as a 0600 file in his home.
# Plain import (`import ./heph-common.nix { inherit pkgs lib; }`), not a module.
{ pkgs, lib }:
rec {
  hephTag = "v1.7.0"; # cargo-installed at this tag by the per-user install oneshots
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

  # The systemd quartet for one user's spoke:
  #   <prefix>-install (oneshot)  — idempotent `cargo install` at hephTag via a
  #     mise-resolved rust toolchain; version-checks so re-runs are no-ops.
  #   <prefix>-install (timer)    — fires the install shortly after boot/switch,
  #     keeping the (first-run ~tens of minutes) compile OFF the activation path.
  #   <prefix>-spoke (service)    — the hephd daemon. ConditionPathExists on the
  #     hephd binary means pre-install it is cleanly *skipped*, not failed, so
  #     bootstrap never shows a failed unit.
  #   <prefix>-spoke (path)       — starts the spoke the moment the install
  #     produces the binary (and at boot when it already exists).
  # The caller supplies the spoke launcher (`spokeExec`) since the token store
  # and PATH needs differ per spoke.
  mkSpokeStack = { prefix, user, group, home, spokeExec, who }:
    let
      cargoBin = "${home}/.cargo/bin";
      install = pkgs.writeShellScript "${prefix}-install" ''
        set -eu
        export HOME=${home}
        export PATH="${lib.makeBinPath [ pkgs.mise pkgs.gcc pkgs.pkg-config pkgs.binutils pkgs.gnumake pkgs.coreutils pkgs.gitMinimal pkgs.gawk ]}:$PATH"
        export CC=gcc
        export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev buildDeps)}"
        target="${lib.removePrefix "v" hephTag}"
        have="$(${cargoBin}/hephd --version 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' || true)"
        if [ "$have" = "$target" ]; then
          echo "heph $target already installed"; exit 0
        fi
        echo "installing heph ${hephTag} (rust@${rustChannel} via mise)…"
        # Retry: a Type=oneshot won't auto-restart, and the mise toolchain
        # download / cargo fetch can flake transiently on a cold cache.
        for attempt in 1 2 3; do
          if mise x rust@${rustChannel} -- cargo install --locked --force \
              --git ${repoHttps} --tag ${hephTag} heph hephd; then
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
      services = {
        "${prefix}-install" = {
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
      timers."${prefix}-install" = {
        description = "Trigger ${prefix}-install off the activation path";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          Persistent = true;
        };
      };
      paths."${prefix}-spoke" = {
        description = "Start ${who}'s heph spoke once hephd is installed";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathExists = "${cargoBin}/hephd";
      };
    };
}
