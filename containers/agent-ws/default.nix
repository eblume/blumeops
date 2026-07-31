# Nix-built image for the containerized ringtail-agent workspace.
#
# This carries the agent's *toolchain* only. `claude` itself is NOT baked in —
# Remote Control moves fast and is self-updating, so (per the decision in
# [[agent-containerization]]) it installs at pod-start onto the persistent PVC
# via Anthropic's official installer, exactly as the host model installs it into
# ~agent/.local/bin today. The image rebuilds only when the toolchain changes,
# not on every claude release.
#
# Two things make this different from a normal app container, both handled
# below and flagged for the on-box smoke test:
#   1. `claude` (and mise's prebuilt rust) are dynamically-linked ELF binaries;
#      a pure dockerTools image is non-FHS, so we symlink the glibc loader and
#      expose a runtime LD_LIBRARY_PATH — the container analogue of nix-ld.
#   2. Remote Control needs a PTY; the entrypoint runs it under `script`.
#
# Built by the standard `Build Container` workflow on nix-container-builder,
# pushed to registry.ops.eblu.me — same as every other container here.
#
# Self-pins nixos-unstable (navidrome/mealie precedent); reuses the shared
# pinned rev+hash so no new hash fetch is needed.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  # allowUnfree: the 1Password CLI (_1password-cli) is unfree.
  pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  lib = pkgs.lib;

  # ── the curated toolchain (mirrors nixos/ringtail/agent-workspaces.nix) ──────
  # op: real 1Password CLI. In a pod the service-account token arrives as
  #   OP_SERVICE_ACCOUNT_TOKEN from a k8s Secret, so plain `op` works — the host
  #   op-shim (which injected the token from a file) is unnecessary here.
  # report toolchain: mise + uv drive research's `uv run --script` tasks; pandoc/
  #   typst/weasyprint for document conversion (weasyprint's native libs go on
  #   LD_LIBRARY_PATH via reportLibs in the entrypoint).
  # cli toolbox: the staples a shell agent reaches for (awk/jq/curl/python3).
  # build toolchain: gcc/binutils/pkg-config/make so `cargo build` links; rust
  #   itself still comes from mise (nixpkgs rustc lags), same as the host.
  reportTools = with pkgs; [ mise uv pandoc typst python3Packages.weasyprint ];
  reportLibs = with pkgs; [ pango glib harfbuzz fontconfig freetype gdk-pixbuf cairo libffi ];
  cliTools = with pkgs; [ gawk jq curl python3 ];
  buildTools = with pkgs; [ gcc binutils pkg-config gnumake ];
  baseTools = with pkgs; [
    _1password-cli git openssh tea coreutils bash cacert tzdata
    gnused gnugrep gnutar gzip which findutils
  ];

  # Prebuilt-binary runtime libs (claude, mise's rust): glibc provides the loader
  # we symlink below; libstdc++ + zlib cover the common dynamic deps. Exposed on
  # LD_LIBRARY_PATH in the entrypoint.
  ldLibs = with pkgs; [ glibc stdenv.cc.cc.lib zlib ];

  allTools = baseTools ++ reportTools ++ cliTools ++ buildTools;

  # Pinned forge SSH host key (public) so the bot's git push verifies the host —
  # same key as environment.etc."agents/ssh/known_hosts" on the host.
  knownHosts = pkgs.writeText "known_hosts" ''
    [forge.ops.eblu.me]:2222 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDlGQT5w03XxlhmEiDVtGq2SkhLIZU4vYhdMey/T2tFLp7kEiOwCWgDgbBn12VDfqXTXJreykBuREqYNSx4tL4Znwap0+HjLOjTIVri8af2ZFF6IP52pcmJEOnxm/yUZhJCosu1wOZwLOoQEPBYM6sPN4OY9PFOsrsxMO2LWPJAZujPlnsfKOTsIS5iRpiT4yU7Z+oWB21rMxjZ9sXZRn8PI2MbUIs/Yazpah2XPJm2YJ7C+kqTLmld4mXQaQtHhzvPaRNB59RS8xyinuaRs618tD3DQq3Qpt8ZZKZydLVv4CIrGvjdqavt0l+4rsNGBh8dWvDR7l2Z6wo9ggDCej957+J6tInfZ82KHSW3ONdm2mUOHObUVSte2xUPlRpnIBFt3lcCapifPULE7PuN0Xdw4r+ewr+6R65RzdptqGfKyyAYsERhbq904ryNZ9fy30vH8+j9imL5AhMkCbP8S/UW49rDIdfN6MvZlX9MoBhmbrkv+kETB7qz9zaOrocEOZOE3fzB9iZxNwlXjstUnjkqi4P1yY/SKpyLC/yDCUpxC79FbCAKIJwar3C2mZaLeBGyqL31HPKOx175VsSxIbjeJX8uNO9WhbFPlcbRETeEoq+dczeU25OESCyyelGb72tTNJYObn2R8Br9NFPiwGZJX6TLlKqaE7x3D0M64ncTJQ==
  '';

  # ── entrypoint ───────────────────────────────────────────────────────────
  # Fuses the host's reposInit + wsRunner + claude-install into one pod entry.
  # Path/secret assumptions are env-overridable so the Deployment owns the
  # concrete mount points:
  #   HOME                        persistent PVC (claude, OAuth cred, repo pool)
  #   OP_SERVICE_ACCOUNT_TOKEN    agents-vault token (k8s Secret, envFrom)
  #   AGENT_BOT_KEY               Forgejo bot SSH key (mounted Secret, 0400)
  # forge/fork bases match the host launcher (canonical read via upstream, push
  # to the agents/ fork).
  entrypoint = pkgs.writeShellScriptBin "agent-ws-entrypoint" ''
    set -eu
    export HOME="''${HOME:-/home/agent}"
    export PATH="${lib.makeBinPath allTools}:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export TZDIR="${pkgs.tzdata}/share/zoneinfo"

    # Dynamic-loader shim for prebuilt binaries (claude, mise rust). See ldLibs.
    export LD_LIBRARY_PATH="${lib.makeLibraryPath (ldLibs ++ reportLibs)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Native build env (cargo linker + weasyprint render path already covered by
    # LD_LIBRARY_PATH above).
    export CC=gcc
    export MISE_TRUSTED_CONFIG_PATHS="$HOME/code/personal"

    # Git identity for the bot's commits.
    export GIT_AUTHOR_NAME=agents GIT_AUTHOR_EMAIL=blume.erich+agents@gmail.com
    export GIT_COMMITTER_NAME=agents GIT_COMMITTER_EMAIL=blume.erich+agents@gmail.com

    bot_key="''${AGENT_BOT_KEY:-/etc/agents/ssh/id_ed25519}"
    export GIT_SSH_COMMAND="ssh -i $bot_key -o IdentitiesOnly=yes -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes"

    forge="ssh://forgejo@forge.ops.eblu.me:2222/eblume"
    fork="ssh://forgejo@forge.ops.eblu.me:2222/agents"
    code="$HOME/code/personal"
    mkdir -p "$code"

    # ── install/update claude onto the PVC (self-updating installer) ──────────
    if [ ! -x "$HOME/.local/bin/claude" ]; then
      echo "agent-ws: installing claude via official installer…" >&2
      curl -fsSL https://claude.ai/install.sh | bash
    fi

    # ── FORGEJO_TOKEN + tea config (op reads the agents-vault PAT) ────────────
    FORGEJO_TOKEN="$(op read "op://agents/agents-forgejo-token/api-token" </dev/null 2>/dev/null || true)"
    export FORGEJO_TOKEN
    install -d -m 700 "$HOME/.config/tea"
    printf 'logins:\n  - name: forge\n    url: https://forge.ops.eblu.me\n    token: %s\n    default: true\n' \
      "$FORGEJO_TOKEN" > "$HOME/.config/tea/config.yml"
    chmod 600 "$HOME/.config/tea/config.yml"

    # ── repo pool: primary + siblings (canonical), blumeops via fork ──────────
    clone_repo() {
      dest="$code/$1"
      if [ -d "$dest/.git" ]; then git -C "$dest" fetch --quiet --all --prune || true
      else git clone --quiet "$forge/$1.git" "$dest"; fi
    }
    clone_fork() {
      dest="$code/$1"
      [ -d "$dest/.git" ] || git clone --quiet "$fork/$1.git" "$dest"
      git -C "$dest" remote set-url origin "$fork/$1.git" 2>/dev/null || git -C "$dest" remote add origin "$fork/$1.git"
      if git -C "$dest" remote | grep -qx upstream; then git -C "$dest" remote set-url upstream "$forge/$1.git"
      else git -C "$dest" remote add upstream "$forge/$1.git"; fi
      git -C "$dest" fetch --quiet --all --prune || true
    }
    for r in agents hephaestus hephaestus.nvim research; do clone_repo "$r"; done
    clone_fork blumeops

    # ── launch Remote Control under a PTY (no --headless flag yet) ────────────
    cd "$code/agents"
    export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=ringtail
    exec ${pkgs.util-linux}/bin/script -qfc \
      "$HOME/.local/bin/claude remote-control --spawn worktree --name ringtail-agent" /dev/null
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/agent-ws";

  contents = allTools ++ [ entrypoint pkgs.util-linux ];

  # Non-FHS fixups: the dynamic loader at its conventional path (so prebuilt
  # ELF binaries run) and a /tmp for tooling that assumes it exists.
  extraCommands = ''
    mkdir -p lib64 tmp
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    chmod 1777 tmp
  '';

  config = {
    Entrypoint = [ "${entrypoint}/bin/agent-ws-entrypoint" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    # Matches the agent uid/gid pinned on the host (users.users.agent.uid = 1500).
    User = "1500:1500";
    WorkingDir = "/home/agent";
  };
}
