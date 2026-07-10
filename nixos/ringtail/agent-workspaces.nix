# Agent Workspaces — per-repo Claude Code Remote Control servers.
#
# See docs/reference/infrastructure/agent-workspaces.md for the design and
# docs/how-to/ringtail/bootstrap-agent-workspaces.md for one-time setup.
#
# Secrets placed by ansible (ansible/playbooks/ringtail.yml), NOT nix:
#   /etc/agents/op-token          agents-ringtail-rw service-account token (0400 agent)
#   /etc/agents/ssh/id_ed25519    Forgejo bot private key (0400 agent)
{ config, pkgs, lib, ... }:

let
  agentHome = "/home/agent";
  opToken = "/etc/agents/op-token";
  botKey = "/etc/agents/ssh/id_ed25519";
  knownHosts = "/etc/agents/ssh/known_hosts";
  claudeBin = "${agentHome}/.local/bin/claude";
  forgeBase = "ssh://forgejo@forge.ops.eblu.me:2222/eblume";

  # Workspace definitions. `primary` is the repo Remote Control roots in (cwd);
  # `also` are sibling checkouts cloned alongside for reference. A null primary
  # means an empty git repo (the playground).
  #
  # blumeops is deliberately NOT a workspace: real blumeops work needs the whole
  # blumeops 1Password vault (its ansible pre_tasks and mise tasks `op read`
  # broadly), and that vault is intentionally the operational-secret blast-radius
  # boundary — there is no least-privilege subset to hand a service account, and
  # a headless service account can't do biometric `op`. So blumeops stays a
  # local-on-gilbert, biometric-`op` job. See agent-workspaces.md §"Why blumeops
  # is not a workspace".
  workspaces = {
    hephaestus = { primary = "hephaestus"; also = [ "hephaestus.nvim" ]; };
    research = { primary = "research"; also = [ ]; };
    playground = { primary = null; also = [ ]; };
  };

  # Transparent `op` shim: inject the service-account token, exec the real op.
  # Prepended to workspace PATH so plain `op` works without exporting the token.
  opShim = pkgs.writeShellScriptBin "op" ''
    if [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -r ${opToken} ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${opToken})"
      export OP_SERVICE_ACCOUNT_TOKEN
    fi
    exec ${pkgs._1password-cli}/bin/op "$@"
  '';

  # ── heph spoke ────────────────────────────────────────────────────────────
  # The agent runs a hephd *spoke* synced to the indri hub, so agent sessions can
  # use heph for task/context — heph is an in-boundary agentic-workflow substrate,
  # not isolated out (unlike the blumeops vault). See agent-workspaces.md.
  cargoBin = "${agentHome}/.cargo/bin";
  hephTag = "v1.7.0"; # cargo-installed at this tag by agent-heph-install
  rustChannel = "stable"; # mise-resolved toolchain — nixpkgs rustc lags heph's floor
  hephHubUrl = "http://indri.tail8d86e.ts.net:8787"; # spoke sync is HTTP-only
  hephIssuer = "https://authentik.ops.eblu.me/application/o/heph/";
  hephTokenRef = "op://agents/heph-spoke-token/token"; # in the agents vault
  # Anonymous HTTPS clone for the build (public repo) — no SSH host key / bot key,
  # matching the ansible heph role + hephd self-update (forgeBase is SSH-only).
  hephRepoHttps = "https://forge.eblu.me/eblume/hephaestus.git";

  # System libraries `cargo install heph hephd` needs to build (dbus for the
  # compiled-in keyring backend, even though the spoke uses the command store).
  hephBuildDeps = with pkgs; [ dbus openssl sqlite zlib ];

  # Persist the spoke's OIDC token in the agents 1Password vault (no plaintext at
  # rest). Reads the token JSON on stdin (from hephd `--token-save-cmd`) and
  # writes it to a CONCEALED field — NEVER via argv (`/proc/<pid>/cmdline` is
  # world-readable), using op template files + `jq --rawfile`.
  hephTokenSave = pkgs.writeShellScriptBin "heph-token-save" ''
    set -eu
    umask 077
    d="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap '${pkgs.coreutils}/bin/rm -rf "$d"' EXIT
    ${pkgs.coreutils}/bin/cat > "$d/token" # token JSON on stdin
    if ${opShim}/bin/op item get heph-spoke-token --vault agents --format json </dev/null > "$d/item.json" 2>/dev/null; then
      ${pkgs.jq}/bin/jq --rawfile t "$d/token" \
        '(.fields |= map(if .label == "token" then .value = $t else . end))' \
        "$d/item.json" > "$d/new.json"
      ${opShim}/bin/op item edit heph-spoke-token --vault agents --template "$d/new.json" </dev/null >/dev/null
    else
      ${pkgs.jq}/bin/jq -n --rawfile t "$d/token" \
        '{title: "heph-spoke-token", category: "API_CREDENTIAL", fields: [{label: "token", type: "CONCEALED", value: $t}]}' \
        > "$d/new.json"
      ${opShim}/bin/op item create --vault agents --template "$d/new.json" </dev/null >/dev/null
    fi
  '';

  # Idempotent install of heph+hephd at ${hephTag}. mise resolves a current rust
  # toolchain (nixpkgs rustc is behind heph's floor); recompiles only when the
  # installed version differs from the pin. First run compiles the workspace.
  hephInstall = pkgs.writeShellScript "agent-heph-install" ''
    set -eu
    export HOME=${agentHome}
    export PATH="${lib.makeBinPath [ pkgs.mise pkgs.gcc pkgs.pkg-config pkgs.binutils pkgs.gnumake pkgs.coreutils pkgs.gitMinimal pkgs.gawk ]}:$PATH"
    export CC=gcc
    export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev hephBuildDeps)}"
    target="${lib.removePrefix "v" hephTag}"
    have="$(${cargoBin}/hephd --version 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' || true)"
    if [ "$have" = "$target" ]; then
      echo "heph $target already installed"; exit 0
    fi
    echo "installing heph ${hephTag} (rust@${rustChannel} via mise)…"
    # Retry: a Type=oneshot won't auto-restart, and the mise toolchain download /
    # cargo fetch can flake transiently on a cold cache.
    for attempt in 1 2 3; do
      if mise x rust@${rustChannel} -- cargo install --locked --force \
          --git ${hephRepoHttps} --tag ${hephTag} heph hephd; then
        exit 0
      fi
      echo "heph install attempt $attempt failed; retrying in 15s…" >&2
      sleep 15
    done
    echo "heph install failed after 3 attempts" >&2
    exit 1
  '';

  # The spoke daemon. Shares the default socket/db with agent sessions' `heph`
  # CLI (same user + HOME), so a session's `heph` talks to this daemon.
  hephSpoke = pkgs.writeShellScript "agent-heph-spoke" ''
    export HOME=${agentHome}
    export PATH="${opShim}/bin:${hephTokenSave}/bin:${lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}:${cargoBin}:$PATH"
    exec ${cargoBin}/hephd --mode local \
      --hub-url ${hephHubUrl} \
      --oidc-issuer ${hephIssuer} \
      --oidc-client-id heph \
      --token-load-cmd "${opShim}/bin/op read ${hephTokenRef}" \
      --token-save-cmd "heph-token-save"
  '';

  wsDir = name: "${agentHome}/workspaces/${name}";
  # Remote Control cwd: the primary repo checkout, or the playground dir itself.
  wsCwd = name: ws: if ws.primary == null then wsDir name else "${wsDir name}/${ws.primary}";

  # Clone-or-update one repo into a workspace.
  cloneRepo = name: repo: ''
    dest="${wsDir name}/${repo}"
    if [ -d "$dest/.git" ]; then
      git -C "$dest" fetch --quiet --all --prune || true
    else
      git clone --quiet "${forgeBase}/${repo}.git" "$dest"
    fi
  '';

  reposForWorkspace = name: ws:
    (lib.optional (ws.primary != null) ws.primary) ++ ws.also;

  # Oneshot: prepare every workspace's checkouts before the servers start.
  reposInit = pkgs.writeShellScript "agent-repos-init" ''
    set -eu
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botKey} -o IdentitiesOnly=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes"
    export PATH="${lib.makeBinPath [ pkgs.git pkgs.openssh ]}:$PATH"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: ws: ''
      mkdir -p "${wsDir name}"
      ${lib.concatMapStringsSep "\n" (cloneRepo name) (reposForWorkspace name ws)}
      ${lib.optionalString (ws.primary == null) ''
        if [ ! -d "${wsCwd name ws}/.git" ]; then
          git -C "${wsCwd name ws}" init --quiet
          git -C "${wsCwd name ws}" commit --quiet --allow-empty -m "playground" || true
        fi
      ''}
    '') workspaces)}
  '';

  # Per-workspace launcher. `script` allocates a PTY (Remote Control needs a
  # TTY); the op shim leads PATH so agent sessions get token-injected `op`.
  wsRunner = name: ws: pkgs.writeShellScript "agent-ws-${name}" ''
    export HOME=${agentHome}
    export PATH="${opShim}/bin:${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils pkgs.tea ]}:$HOME/.local/bin:${cargoBin}:$PATH"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botKey} -o IdentitiesOnly=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes"
    export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=ringtail

    # Git identity for the bot's commits — without it `git commit` fails with
    # "Author identity unknown", so hephaestus/research couldn't commit either.
    export GIT_AUTHOR_NAME=agents GIT_AUTHOR_EMAIL=blume.erich+agents@gmail.com
    export GIT_COMMITTER_NAME=agents GIT_COMMITTER_EMAIL=blume.erich+agents@gmail.com

    # Forgejo API token (agents-owned, write:repository only) so agents can open
    # PRs. Fetched via the op shim from the AGENTS vault — no blumeops-vault
    # dependency. Exported as FORGEJO_TOKEN (the pr-comments/branch-cleanup/
    # runner-logs mise tasks honor it ahead of their blumeops-vault fallback)
    # and written to tea's config so `tea pr create` works non-interactively.
    # Least-privilege: an agents-owned PAT cannot exceed agents' own repo access
    # (hephaestus, hephaestus.nvim, research) regardless of scope.
    FORGEJO_TOKEN="$(op read "op://agents/agents-forgejo-token/api-token" 2>/dev/null || true)"
    export FORGEJO_TOKEN
    install -d -m 700 "$HOME/.config/tea"
    tea_tmp="$(mktemp)"
    printf 'logins:\n  - name: forge\n    url: https://forge.ops.eblu.me\n    token: %s\n    default: true\n' "$FORGEJO_TOKEN" > "$tea_tmp"
    chmod 600 "$tea_tmp"
    mv -f "$tea_tmp" "$HOME/.config/tea/config.yml"

    cd "${wsCwd name ws}"
    exec ${pkgs.util-linux}/bin/script -qfc \
      "${claudeBin} remote-control --spawn worktree --name ringtail-${name}" /dev/null
  '';

  mkWorkspaceService = name: ws: {
    name = "agent-ws-${name}";
    value = {
      description = "Claude Code Remote Control workspace: ${name}";
      after = [ "network-online.target" "agent-repos-init.service" ];
      wants = [ "network-online.target" ];
      requires = [ "agent-repos-init.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "agent";
        Group = "agent";
        WorkingDirectory = wsCwd name ws;
        ExecStart = wsRunner name ws;
        Restart = "always";
        RestartSec = 10;
        # Remote Control renders a status TUI that redraws ~10x/second; piping
        # that to the journal is ~1M lines/day per workspace. Discard stdout;
        # keep stderr so real errors and crashes are still captured.
        StandardOutput = "null";
        StandardError = "journal";
        # Modest hardening. NOT a strong sandbox — the real boundaries are the
        # `agent` user, the vault-scoped token, and (later) containerization.
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };
  };
in
{
  # Forge SSH host key (public, pinned) for the agent bot's git operations.
  environment.etc."agents/ssh/known_hosts".text = ''
    [forge.ops.eblu.me]:2222 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDlGQT5w03XxlhmEiDVtGq2SkhLIZU4vYhdMey/T2tFLp7kEiOwCWgDgbBn12VDfqXTXJreykBuREqYNSx4tL4Znwap0+HjLOjTIVri8af2ZFF6IP52pcmJEOnxm/yUZhJCosu1wOZwLOoQEPBYM6sPN4OY9PFOsrsxMO2LWPJAZujPlnsfKOTsIS5iRpiT4yU7Z+oWB21rMxjZ9sXZRn8PI2MbUIs/Yazpah2XPJm2YJ7C+kqTLmld4mXQaQtHhzvPaRNB59RS8xyinuaRs618tD3DQq3Qpt8ZZKZydLVv4CIrGvjdqavt0l+4rsNGBh8dWvDR7l2Z6wo9ggDCej957+J6tInfZ82KHSW3ONdm2mUOHObUVSte2xUPlRpnIBFt3lcCapifPULE7PuN0Xdw4r+ewr+6R65RzdptqGfKyyAYsERhbq904ryNZ9fy30vH8+j9imL5AhMkCbP8S/UW49rDIdfN6MvZlX9MoBhmbrkv+kETB7qz9zaOrocEOZOE3fzB9iZxNwlXjstUnjkqi4P1yY/SKpyLC/yDCUpxC79FbCAKIJwar3C2mZaLeBGyqL31HPKOx175VsSxIbjeJX8uNO9WhbFPlcbRETeEoq+dczeU25OESCyyelGb72tTNJYObn2R8Br9NFPiwGZJX6TLlKqaE7x3D0M64ncTJQ==
  '';

  # uid/gid pinned so ansible can chown /etc/agents/* numerically before the
  # user exists in passwd on a first-ever deploy (secrets are written in
  # pre_tasks, the user is created later by nixos-rebuild).
  users.groups.agent.gid = 1500;
  users.users.agent = {
    isNormalUser = true;
    uid = 1500;
    home = agentHome;
    group = "agent";
    shell = pkgs.bash;
    description = "Claude Code agent workspaces (unprivileged)";
    # No extraGroups: deliberately not in wheel, networkmanager, or onepassword-cli.
  };

  systemd.services = {
    agent-repos-init = {
      description = "Prepare Claude Code agent workspace checkouts";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "agent";
        Group = "agent";
        ExecStart = reposInit;
      };
    };

    # Build+install heph/hephd for the agent (mise-resolved rust). Oneshot; first
    # run compiles the workspace (~tens of min), then it's a version-check no-op.
    # Triggered by agent-heph-install.timer — deliberately NOT wantedBy a target,
    # so the long compile never blocks `nixos-rebuild switch` activation.
    agent-heph-install = {
      description = "Install heph+hephd for the agent (mise rust + cargo install)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "agent";
        Group = "agent";
        ExecStart = hephInstall;
        # First build compiles the whole workspace from a cold cargo cache.
        TimeoutStartSec = "45min";
      };
    };

    # The agent's hephd spoke, synced to the indri hub. Does NOT `requires` the
    # install (that would drag the compile onto the activation path); instead it
    # Restart=always-retries until the install timer has produced hephd. No start
    # rate-limit so it keeps retrying across a long first build.
    agent-heph-spoke = {
      description = "Claude Code agent heph spoke (hephd synced to the indri hub)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        User = "agent";
        Group = "agent";
        ExecStart = hephSpoke;
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
  } // lib.listToAttrs (lib.mapAttrsToList mkWorkspaceService workspaces);

  # Kick the (potentially long) heph build off the activation path: the timer
  # fires shortly after boot / switch and triggers agent-heph-install, so
  # `nixos-rebuild switch` never waits on a cold cargo compile.
  systemd.timers.agent-heph-install = {
    description = "Trigger agent-heph-install off the activation path";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      Persistent = true;
    };
  };
}
