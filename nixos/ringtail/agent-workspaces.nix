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
  # Fork namespace. The bot has only READ on the canonical blumeops (so it can't
  # push to it or dispatch its deploy-credentialed CI); it authors via its own
  # fork under `agents/` and opens cross-repo PRs. See forkRepos / cloneForkRepo.
  forkBase = "ssh://forgejo@forge.ops.eblu.me:2222/agents";

  # The single home-base workspace. `primary` is the repo Remote Control roots
  # in (cwd) — the `agents` repo, whose AGENTS.md carries the base instructions
  # every remote session wakes up with. `also` are sibling checkouts cloned
  # alongside for the session to `cd` into. Sessions spawn as worktrees of the
  # PRIMARY only; siblings are SHARED between concurrent sessions, so the base
  # instructions tell agents to work siblings on session-named branches.
  # Per-repo servers were superseded 2026-07-11 — see agent-workspaces.md
  # §"Why one home-base server".
  workspaces = {
    agent = {
      primary = "agents";
      # timberborn-parsimony builds against the game's Managed/ DLLs under
      # /mnt/games (world-readable); launching the game itself stays a
      # human-session job — see that repo's AGENTS.md.
      also = [ "hephaestus" "hephaestus.nvim" "research" "timberborn-parsimony" ];
    };
  };

  # Fork-based pool checkouts: cloned into ~/code/personal alongside the
  # workspace repos so any session can `cd` in to *author* changes and open PRs —
  # WITHOUT a per-repo server. blumeops lives here (public, secret-free). The bot
  # has only READ on the canonical repo, so it works through its fork: origin =
  # agents/<repo> (push), upstream = eblume/<repo> (fetch canonical main); branch
  # off upstream/main, PRs are cross-repo. Read-only + fork is what stops the bot
  # dispatching blumeops' deploy-credentialed CI — the real deploy gate, on top of
  # holding neither the blumeops 1Password vault nor cluster access (k3s kubeconfig
  # 0600 root-only, non-`wheel`, no sudo). The agent-owned clone is distinct from
  # the root-owned deploy checkout at /etc/blumeops. See agent-workspaces.md
  # §"blumeops: author-only, not a server".
  forkRepos = [ "blumeops" ];

  # Transparent `op` shim: inject the service-account token, exec the real op.
  # Prepended to workspace PATH so plain `op` works without exporting the token.
  opShim = pkgs.writeShellScriptBin "op" ''
    if [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -r ${opToken} ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${opToken})"
      export OP_SERVICE_ACCOUNT_TOKEN
    fi
    exec ${pkgs._1password-cli}/bin/op "$@"
  '';

  # ── report toolchain ──────────────────────────────────────────────────────
  # The research workspace's `mise run compile-report` / `save-session` tasks are
  # `uv run --script` programs, so agent sessions need mise + uv on PATH. pandoc
  # and typst are added as handy document converters. WeasyPrint's `compile-report`
  # pip-installs WeasyPrint into uv's *ephemeral* venv; that venv can only render a
  # PDF if WeasyPrint's native libraries (Pango and friends) are discoverable. nix
  # store libs sit in no default loader path, so we expose them via LD_LIBRARY_PATH
  # in the session env below — the Linux counterpart of the repo's macOS Brewfile
  # (pango/gdk-pixbuf/libffi). `pkgs.weasyprint` is also on PATH so `weasyprint`
  # resolves as a CLI, but the render path is the uv venv, not this binary.
  reportTools = with pkgs; [ mise uv pandoc typst python3Packages.weasyprint ];
  reportLibs = with pkgs; [ pango glib harfbuzz fontconfig freetype gdk-pixbuf cairo libffi ];

  # ── general CLI toolbox ────────────────────────────────────────────────────
  # The staples a plain shell agent reaches for constantly to munge text/JSON and
  # write quick scripts. Without them sessions fall back to slower workarounds
  # (WebFetch instead of `curl`, a whole `uv run --script` instead of a `python3`
  # one-liner) or simply fail on `awk`/`jq` pipelines. `gawk` provides `awk`;
  # `curl` for HTTP; `jq` for JSON. `python3` is a bare interpreter for one-liners
  # and stdlib (json, etc.) — `uv` is already on PATH via reportTools for
  # `uv run --script`, but a plain `python3`/`python` is what one-off snippets want.
  cliTools = with pkgs; [ gawk jq curl python3 ];

  # ── native build toolchain ────────────────────────────────────────────────
  # Interactive sessions had no C toolchain, so `cargo build` (and anything that
  # links) failed with `linker `cc` not found`: the heph *install* oneshot has
  # its own gcc/pkg-config env (hephBuildDeps, below), but sessions did not.
  # Surface a real toolchain so agents can build & verify Rust — notably the
  # `gamedev` Bevy project. Rust itself still comes from mise (nixpkgs rustc lags,
  # same as the heph install); this just supplies the linker + pkg-config. Running
  # a windowed Bevy app needs a GPU/display this headless box lacks, but
  # `cargo build`/`cargo check` verification works.
  buildTools = with pkgs; [ gcc binutils pkg-config gnumake ];
  # Bevy's Linux native deps. alsa (audio) & udev (gamepad) are pkg-config-probed
  # at build time; the windowing/graphics libs (wayland, xkbcommon, vulkan, X11,
  # GL) are dlopen'd at run time. Expose the dev outputs to pkg-config (build) and
  # the runtime libs to the loader — the same trick reportLibs uses for WeasyPrint.
  gameBuildDeps = with pkgs; [ alsa-lib udev ];
  gameLibs = with pkgs; [
    alsa-lib udev vulkan-loader libxkbcommon wayland libGL
    xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr
  ];

  # ── heph spoke ────────────────────────────────────────────────────────────
  # The agent runs a hephd *spoke* synced to the indri hub, so agent sessions can
  # use heph for task/context — heph is an in-boundary agentic-workflow substrate,
  # not isolated out (unlike the blumeops vault). See agent-workspaces.md.
  cargoBin = "${agentHome}/.cargo/bin";
  # Shared spoke plumbing (version pin, hub/OIDC endpoints, install machinery) —
  # heph-eblume.nix builds Erich's own spoke from the same file, so the two
  # spokes can't drift apart on the heph version.
  heph = import ./heph-common.nix { inherit pkgs lib; };
  hephTokenRef = "op://agents/heph-spoke-token/token"; # in the agents vault

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

  # The spoke daemon. Shares the default socket/db with agent sessions' `heph`
  # CLI (same user + HOME), so a session's `heph` talks to this daemon. The
  # spoke ADOPTS the hub's owner id: the `heph-agents` credential is only the
  # login identity (revocable), not a separate data owner.
  hephSpoke = pkgs.writeShellScript "agent-heph-spoke" ''
    export HOME=${agentHome}
    # pkgs.bash provides `sh`: hephd's command token store runs the load/save
    # commands via `Command::new("sh")`, which does a PATH lookup — without a
    # shell on PATH the token never loads and every hub sync 401s.
    export PATH="${opShim}/bin:${hephTokenSave}/bin:${lib.makeBinPath [ pkgs.jq pkgs.coreutils pkgs.bash ]}:${cargoBin}:$PATH"
    exec ${cargoBin}/hephd --mode local \
      --hub-url ${heph.hubUrl} \
      --owner-id ${heph.ownerId} \
      --oidc-issuer ${heph.issuer} \
      --oidc-client-id heph \
      --token-load-cmd "${opShim}/bin/op read ${hephTokenRef}" \
      --token-save-cmd "heph-token-save"
  '';

  # The agent's spoke unit quartet (install oneshot + timer + spoke + path unit)
  # comes from the shared machinery; only the launcher above is agent-specific.
  hephStack = heph.mkSpokeStack {
    prefix = "agent-heph";
    user = "agent";
    group = "agent";
    home = agentHome;
    spokeExec = hephSpoke;
    who = "the agent";
  };

  # Repos live at ~/code/personal/<repo> so the paths agents read in the repo
  # docs (every AGENTS.md/CLAUDE.md assumes ~/code/personal/…) actually resolve on
  # the agent box too. The workspace NAME still names the Remote Control session
  # (ringtail-<name>) — that is independent of where the checkout lives.
  codeDir = "${agentHome}/code/personal";
  repoDir = repo: "${codeDir}/${repo}";
  # Remote Control cwd: the primary repo checkout.
  wsCwd = ws: repoDir ws.primary;

  # Clone-or-update one repo into ~/code/personal.
  cloneRepo = repo: ''
    dest="${repoDir repo}"
    if [ -d "$dest/.git" ]; then
      git -C "$dest" fetch --quiet --all --prune || true
    else
      git clone --quiet "${forgeBase}/${repo}.git" "$dest"
    fi
  '';

  # Fork-based clone-or-update: origin = the bot's fork (push target), upstream =
  # the canonical repo (fetch main). Idempotent — it also repoints an existing
  # canonical-origin clone, so migrating an already-checked-out repo needs no
  # manual `git remote` surgery: the next agent-repos-init run fixes it.
  cloneForkRepo = repo: ''
    dest="${repoDir repo}"
    if [ ! -d "$dest/.git" ]; then
      git clone --quiet "${forkBase}/${repo}.git" "$dest"
    fi
    git -C "$dest" remote set-url origin "${forkBase}/${repo}.git" 2>/dev/null \
      || git -C "$dest" remote add origin "${forkBase}/${repo}.git"
    if git -C "$dest" remote | grep -qx upstream; then
      git -C "$dest" remote set-url upstream "${forgeBase}/${repo}.git"
    else
      git -C "$dest" remote add upstream "${forgeBase}/${repo}.git"
    fi
    git -C "$dest" fetch --quiet --all --prune || true
  '';

  reposForWorkspace = ws: [ ws.primary ] ++ ws.also;

  # Oneshot: prepare every workspace's checkouts before the servers start.
  reposInit = pkgs.writeShellScript "agent-repos-init" ''
    set -eu
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botKey} -o IdentitiesOnly=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes"
    export PATH="${lib.makeBinPath [ pkgs.git pkgs.openssh ]}:$PATH"
    mkdir -p "${codeDir}"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: ws:
      lib.concatMapStringsSep "\n" cloneRepo (reposForWorkspace ws)) workspaces)}
    # Fork-based pool checkouts (no server): origin = fork, upstream = canonical.
    ${lib.concatMapStringsSep "\n" cloneForkRepo forkRepos}
  '';

  # Per-workspace launcher. `script` allocates a PTY (Remote Control needs a
  # TTY); the op shim leads PATH so agent sessions get token-injected `op`.
  wsRunner = name: ws: pkgs.writeShellScript "agent-ws-${name}" ''
    export HOME=${agentHome}
    export PATH="${opShim}/bin:${lib.makeBinPath ([ pkgs.git pkgs.openssh pkgs.coreutils pkgs.tea ] ++ reportTools ++ cliTools ++ buildTools)}:$HOME/.local/bin:${cargoBin}:$PATH"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${botKey} -o IdentitiesOnly=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes"
    export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=ringtail

    # Report toolchain runtime. WeasyPrint (pip-installed into uv's ephemeral venv
    # by compile-report) dlopens Pango & co.; nix store libs are in no default
    # loader path, so surface them here (the Linux analogue of the repo Brewfile).
    export LD_LIBRARY_PATH="${lib.makeLibraryPath reportLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # Pre-trust the agent's own repo mise configs so `mise run …` never blocks on
    # an interactive trust prompt.
    export MISE_TRUSTED_CONFIG_PATHS="${codeDir}"

    # Native build toolchain env (see buildTools/gameBuildDeps/gameLibs). cargo
    # needs a linker; Bevy's sys crates pkg-config-probe alsa/udev at build, and
    # its windowing/graphics libs are dlopen'd at run — expose both. Prepends to
    # the report LD_LIBRARY_PATH set just above.
    export CC=gcc
    export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev gameBuildDeps)}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath gameLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Git identity for the bot's commits — without it `git commit` fails with
    # "Author identity unknown", so no repo could commit.
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

    cd "${wsCwd ws}"
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
        WorkingDirectory = wsCwd ws;
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

  } // hephStack.services
    // lib.listToAttrs (lib.mapAttrsToList mkWorkspaceService workspaces);

  # Timer + path unit for the agent's heph spoke (see heph-common.nix for why:
  # the compile stays off the activation path, and the spoke starts the moment
  # the install produces hephd — bootstrap never shows a failed unit).
  systemd.timers = hephStack.timers;
  systemd.paths = hephStack.paths;
}
