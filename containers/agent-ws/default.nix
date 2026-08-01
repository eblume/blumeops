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

  # Toolchain-schema version for the image tag (the Build Container workflow
  # requires a `version = "…"` to form v<version>-<sha>-nix). There is no
  # upstream version to track — claude self-installs at pod-start — so bump this
  # by hand when the baked toolchain changes meaningfully.
  version = "0.11.0";

  # ── the repo pool, from ./repos.json ──────────────────────────────────────
  # That file is the single source of truth for BOTH halves of "share a repo
  # with the agent": the forge collaborator grant (reconciled by
  # `mise run agent-repo-access`) and the clone loop below. Keeping them in one
  # file is the point — they used to drift, and a missing grant is invisible
  # (Forgejo 404s rather than 403s on a private repo the bot cannot see).
  repoPolicy = builtins.fromJSON (builtins.readFile ./repos.json);
  poolOf = p: builtins.filter (r: r.pool == p) repoPolicy.repos;
  forkRepos = map (r: r.name) (poolOf "fork");
  canonicalRepos = map (r: r.name) (poolOf "canonical");

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
    _1password-cli git openssh coreutils bash cacert tzdata
    gnused gnugrep gnutar gzip which findutils
  ];

  # tea, wrapped to route through the tag:agent SOCKS sidecar. tea only ever
  # contacts the forge (forge.ops.eblu.me), which the pod can reach ONLY via the
  # proxy, and tea (unlike git) has no per-URL proxy config — so send all of
  # tea's traffic through the proxy. A GLOBAL proxy would be wrong (it'd break
  # claude↔Anthropic and op↔1Password, which must egress directly), hence a
  # tea-specific wrapper. Shadows pkgs.tea on PATH.
  teaWrapper = pkgs.writeShellScriptBin "tea" ''
    export HTTPS_PROXY="socks5h://localhost:1055"
    export HTTP_PROXY="socks5h://localhost:1055"
    exec ${pkgs.tea}/bin/tea "$@"
  '';

  # Prebuilt-binary runtime libs (claude, mise's rust): glibc provides the loader
  # we symlink below; libstdc++ + zlib cover the common dynamic deps. Exposed on
  # LD_LIBRARY_PATH in the entrypoint.
  ldLibs = with pkgs; [ glibc stdenv.cc.cc.lib zlib ];

  # heph CLI, baked in and built against THIS image's nixpkgs so it runs natively
  # (the host's cargo binary won't — its ELF interpreter is a host nix-store glibc
  # path absent here). The pod runs NO hephd; it shares the host agent-heph-spoke
  # daemon via a hostPath-mounted socket (see the Deployment). Build only the
  # `heph` crate — hephd + the GUI crate aren't needed. Pinned to hephTag v1.7.0
  # (matches nixos/ringtail/heph-common.nix). nixpkgs rustc (1.96) clears heph's
  # 1.89 floor, and the lockfile has no git deps, so nix vendors cleanly.
  hephSrc = pkgs.fetchgit {
    url = "https://forge.eblu.me/eblume/hephaestus.git";
    rev = "refs/tags/v1.7.0";
    hash = "sha256-M/wjIWX9Vg4YyItCf18UFgLjzEC6TGlbPJn26iRv7mw=";
  };
  heph = pkgs.rustPlatform.buildRustPackage {
    pname = "heph";
    version = "1.7.0";
    src = hephSrc;
    cargoLock.lockFile = hephSrc + "/Cargo.lock";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.dbus pkgs.openssl pkgs.sqlite pkgs.zlib ];
    cargoBuildFlags = [ "-p" "heph" ];
    doCheck = false;
  };

  # Liveness check for the Deployment's exec probe. The failure mode it catches
  # is a ZOMBIE, not a crash (observed 2026-08-01): remote-control survives a
  # WAN blip as a process but never re-dials Anthropic, so k8s sees a healthy
  # container while every Claude client sees a dead server. Crashes already
  # self-heal (claude exits → script exits → container restarts).
  #
  # Signal: some claude process holds ≥1 ESTABLISHED TCP connection. A healthy
  # remote-control keeps a persistent gateway websocket even when idle; the
  # zombie held only unix sockets. /proc/net/tcp* is netns-WIDE (shared with
  # the ts sidecar, whose control-plane conns are always up), so we must match
  # per-process socket-fd inodes against ESTABLISHED (state 01) rows rather
  # than testing the table globally. arg0-matching skips pid 1 (`script`, whose
  # argv merely *mentions* claude) but covers both the launcher
  # (~/.local/bin/claude) and version binaries (~/.local/share/claude/versions/…).
  healthCheck = pkgs.writeShellScriptBin "agent-ws-health" ''
    est=" $(${pkgs.gawk}/bin/awk '$4=="01" {print $10}' /proc/net/tcp /proc/net/tcp6 2>/dev/null | tr '\n' ' ') "
    for p in /proc/[0-9]*; do
      arg0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -n1)
      case "$arg0" in *claude*) ;; *) continue ;; esac
      for f in "$p"/fd/*; do
        s=$(readlink "$f" 2>/dev/null) || continue
        case "$s" in "socket:["*) i="''${s#socket:[}"; i="''${i%]}" ;; *) continue ;; esac
        case "$est" in *" $i "*) exit 0 ;; esac
      done
    done
    echo "agent-ws-health: no claude process holds an established TCP connection" >&2
    exit 1
  '';

  allTools = baseTools ++ reportTools ++ cliTools ++ buildTools ++ [ heph teaWrapper healthCheck ];

  # ── entrypoint ───────────────────────────────────────────────────────────
  # Fuses the host's reposInit + wsRunner + claude-install into one pod entry.
  # Path/secret assumptions are env-overridable so the Deployment owns the
  # concrete mount points:
  #   HOME                        persistent PVC (claude, OAuth cred, repo pool)
  #   OP_SERVICE_ACCOUNT_TOKEN    agents-vault token (k8s Secret, envFrom)
  # Git talks to the forge over HTTPS+token through the SOCKS sidecar (no ssh
  # key needed — see the git config in the entrypoint body).
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

    # 1Password CLI in a pod (learned the hard way): beyond the /etc/passwd entry
    # baked into the image, op needs a TMPDIR it owns (the container /tmp is
    # root-owned, which op's SingleUserEnvironment check rejects) and all of its
    # state at 0600/0700. fsGroup makes new files group-accessible, and op
    # refuses any group-readable config OR session file. Both dirs persist on the
    # PVC, so a stale 0660 file from a prior pod breaks op on the next boot —
    # patching perms piecemeal is unreliable (op has config + daemon + session
    # files). Reset op's state entirely each boot and let umask 077 recreate it
    # 0600/0700. op is a stateless service-account client, so this is free.
    umask 077
    export TMPDIR="$HOME/.optmp"
    rm -rf "$HOME/.config/op" "$TMPDIR"
    mkdir -p "$TMPDIR"

    # Git identity for the bot's commits.
    export GIT_AUTHOR_NAME=agents GIT_AUTHOR_EMAIL=blume.erich+agents@gmail.com
    export GIT_COMMITTER_NAME=agents GIT_COMMITTER_EMAIL=blume.erich+agents@gmail.com

    # Git over HTTPS+token through the tag:agent SOCKS sidecar — NOT ssh. The
    # forge bot SSH key lives in the agents vault, which external-secrets can't
    # reach; the FORGEJO_TOKEN (op-read below) authenticates over HTTPS instead,
    # and HTTPS-via-SOCKS avoids the ssh-over-SOCKS ProxyCommand dance entirely.
    # Only forge.ops.eblu.me routes through the proxy (tag:agent can reach ONLY
    # indri); public hosts (claude.ai, 1Password, forge.eblu.me) go direct.
    git config --global "http.https://forge.ops.eblu.me/.proxy" "socks5h://localhost:1055"
    git config --global "credential.https://forge.ops.eblu.me.username" "agents"
    askpass="$HOME/.git-askpass"
    printf '#!/bin/sh\nexec printf "%%s" "$FORGEJO_TOKEN"\n' > "$askpass"
    chmod 700 "$askpass"
    export GIT_ASKPASS="$askpass"

    forge="https://forge.ops.eblu.me/eblume"
    fork="https://forge.ops.eblu.me/agents"
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
    # Non-fatal: a clone failure (proxy not ready, etc.) must not abort the
    # entrypoint before Remote Control starts — otherwise the pod crashloops
    # with no way to seed the OAuth login. Warn and continue.
    #
    # Wait for the tag:agent sidecar's SOCKS proxy to route before any git op:
    # the userspace tailscale sidecar takes ~15s to authenticate + establish
    # WireGuard, and git otherwise fails "cannot complete SOCKS5 connection to
    # forge.ops.eblu.me". Bounded (~90s) so a broken sidecar can't hang boot.
    echo "agent-ws: waiting for the tag:agent SOCKS proxy…" >&2
    for _ in $(seq 1 45); do
      curl -sf --max-time 4 -x socks5h://localhost:1055 https://forge.ops.eblu.me/ -o /dev/null 2>/dev/null && break
      sleep 2
    done

    # agents (the home-base instruction substrate) and blumeops both use the
    # FORK model: origin = agents/<repo> (the bot owns it → token push works),
    # upstream = eblume/<repo> (canonical, fetched read-only). Edits go via
    # cross-repo PR — a human gate on changes to the agent's own instructions.
    # The siblings are ordinary author repos cloned canonically.
    #
    # Both lists are GENERATED from ./repos.json — edit that, not this. Most of
    # these are PRIVATE forge repos; they clone over HTTPS with the bot's token
    # only while `agents` is a collaborator, which the same file drives.
    for r in ${lib.escapeShellArgs forkRepos}; do
      clone_fork "$r" || echo "agent-ws: clone $r fork failed (continuing)" >&2
    done
    for r in ${lib.escapeShellArgs canonicalRepos}; do
      clone_repo "$r" || echo "agent-ws: clone $r failed (continuing)" >&2
    done

    # ── launch Remote Control under a PTY (no --headless flag yet) ────────────
    # AGENT_WS_RC_FLAGS is a Deployment-settable escape hatch (e.g. "--verbose"
    # for detailed connection/session logs) so diagnostics can be toggled
    # without an image rebuild — post-2026-08-01-zombie observability lever.
    cd "$code/agents" 2>/dev/null || cd "$HOME"
    export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=ringtail
    exec ${pkgs.util-linux}/bin/script -qfc \
      "$HOME/.local/bin/claude remote-control --spawn worktree --name ringtail-agent ''${AGENT_WS_RC_FLAGS:-}" /dev/null
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/agent-ws";
  tag = "v${version}";

  contents = allTools ++ [ entrypoint pkgs.util-linux ];

  # Non-FHS fixups: the dynamic loader at its conventional path (so prebuilt
  # ELF binaries run), a /tmp, and — critically — /etc/passwd + group + nsswitch
  # so uid 1500 resolves to a username. Without a passwd entry, glibc getpwuid
  # fails and the 1Password CLI's ownership checks ("not owned by the current
  # user") reject every op call, breaking op read entirely in the pod.
  extraCommands = ''
    mkdir -p lib64 tmp etc
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    chmod 1777 tmp
    printf 'root:x:0:0:root:/root:/bin/bash\nagent:x:1500:1500:agent:/home/agent:/bin/bash\n' > etc/passwd
    printf 'root:x:0:\nagent:x:1500:\n' > etc/group
    printf 'passwd: files\ngroup: files\nshadow: files\nhosts: files dns\n' > etc/nsswitch.conf
  '';

  config = {
    Entrypoint = [ "${entrypoint}/bin/agent-ws-entrypoint" ];
    Env = [
      # A default PATH so the toolchain is reachable WITHOUT the entrypoint's own
      # PATH setup — for `kubectl exec` sessions (which the pod-agent reaches into
      # for tools) and for the PVC-chown initContainer, which overrides the
      # entrypoint. The entrypoint still sets its own richer PATH at runtime.
      "PATH=${lib.makeBinPath allTools}:/home/agent/.local/bin:/home/agent/.cargo/bin:/bin"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    # Matches the agent uid/gid pinned on the host (users.users.agent.uid = 1500).
    User = "1500:1500";
    WorkingDir = "/home/agent";
  };
}
