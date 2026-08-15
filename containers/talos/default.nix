# Talos — self-hosted agent workflow service ([[talos-design]]).
#
# Bun runtime + the talos source from the forge + npm deps resolved offline
# via buildNpmPackage (package-lock.json is committed in the talos repo; the
# runtime is still bun — npm only supplies node_modules). A modest shell
# toolchain rides along for the agent's bash tool. Builds on
# nix-container-builder like every other first-party image.
#
# Self-pins nixos-unstable (agent-ws/navidrome/mealie precedent); reuses the
# shared pinned rev+hash so no new hash fetch is needed.
#
# Bumping talos: update `rev` + `srcHash` (and `npmDepsHash` if the lockfile
# changed), then `mise run container-release talos <version>`.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  # allowUnfree: the 1Password CLI (_1password-cli) is unfree.
  pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  lib = pkgs.lib;

  version = "0.2.2";
  rev = "d5bf330d0ad0644b42ab008e3b352e4ca4c9726f";

  src = pkgs.fetchgit {
    url = "https://forge.eblu.me/eblume/talos.git";
    inherit rev;
    hash = "sha256-Yg019wd+nXGZxZnj6l+A/Xcjdul3vadGjysBAQ6x+24=";
  };

  # npm resolves the same registry deps bun would; install scripts are
  # blocked (bun blocks them too — protobufjs/google-genai postinstalls are
  # non-essential).
  app = pkgs.buildNpmPackage {
    pname = "talos";
    inherit version src;
    # v2 fetcher: the v1 cache layout drops nested duplicate entries
    # (pi-coding-agent pins its own pi-* copies), which npm then can't
    # resolve offline.
    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-Tl3iKtXyy+K7yaH3jivctekoD0vjTsTMYx+VTw8G3m8=";
    dontNpmBuild = true;
    npmFlags = [ "--ignore-scripts" ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/app
      cp -r node_modules src public package.json $out/app/
      runHook postInstall
    '';
  };

  # Repo pool shared with agent-ws — ../agent-ws/repos.json is THE source of
  # truth for what the agents bot may touch ([[agents-forgejo-bot]]).
  repoPolicy = builtins.fromJSON (builtins.readFile ../agent-ws/repos.json);
  poolOf = p: builtins.filter (r: r.pool == p) repoPolicy.repos;
  forkRepos = map (r: r.name) (poolOf "fork");
  canonicalRepos = map (r: r.name) (poolOf "canonical");

  # heph CLI — same derivation as agent-ws (pod shares the host spoke's
  # socket via hostPath; no hephd here). Pinned v1.7.0.
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

  # Pod-start bootstrap, mirroring agent-ws: bot git identity, HTTPS+token
  # git through the tag:agent SOCKS sidecar, repo pool clone, then exec the
  # talos server. All bootstrap failures are non-fatal — the UI must come up
  # even if the sidecar is slow.
  entrypoint = pkgs.writeShellScriptBin "talos-entrypoint" ''
    set -u
    export TMPDIR="$HOME/.tmp"
    rm -rf "$HOME/.config/op" "$TMPDIR"
    mkdir -p "$TMPDIR"

    export GIT_AUTHOR_NAME=agents GIT_AUTHOR_EMAIL=blume.erich+agents@gmail.com
    export GIT_COMMITTER_NAME=agents GIT_COMMITTER_EMAIL=blume.erich+agents@gmail.com

    # Git over HTTPS+token through the SOCKS sidecar — NOT ssh (the bot ssh
    # key lives in the agents vault; HTTPS avoids the ProxyCommand dance).
    # Only forge.ops.eblu.me routes through the proxy; public hosts
    # (OpenRouter, Authentik-internal) go direct.
    git config --global "http.https://forge.ops.eblu.me/.proxy" "socks5h://localhost:1055"
    git config --global "credential.https://forge.ops.eblu.me.username" "agents"
    askpass="$HOME/.git-askpass"
    printf '#!/bin/sh
exec printf "%%s" "$FORGEJO_TOKEN"
' > "$askpass"
    chmod 700 "$askpass"
    export GIT_ASKPASS="$askpass"

    FORGEJO_TOKEN="$(op read "op://agents/agents-forgejo-token/api-token" </dev/null 2>/dev/null || true)"
    export FORGEJO_TOKEN
    install -d -m 700 "$HOME/.config/tea"
    printf 'logins:
  - name: forge
    url: https://forge.ops.eblu.me
    token: %s
    default: true
'       "$FORGEJO_TOKEN" > "$HOME/.config/tea/config.yml"
    chmod 600 "$HOME/.config/tea/config.yml"

    forge="https://forge.ops.eblu.me/eblume"
    fork="https://forge.ops.eblu.me/agents"
    code="''${TALOS_WORKSPACE:-$HOME/workspace}"
    mkdir -p "$code"

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

    echo "talos: waiting for the tag:agent SOCKS proxy…" >&2
    for _ in $(seq 1 45); do
      curl -sf --max-time 4 -x socks5h://localhost:1055 https://forge.ops.eblu.me/ -o /dev/null 2>/dev/null && break
      sleep 2
    done

    for r in ${lib.escapeShellArgs forkRepos}; do
      clone_fork "$r" || echo "talos: clone $r fork failed (continuing)" >&2
    done
    for r in ${lib.escapeShellArgs canonicalRepos}; do
      clone_repo "$r" || echo "talos: clone $r failed (continuing)" >&2
    done

    exec ${pkgs.bun}/bin/bun run /app/src/server.ts
  '';

  # Toolchain for the agent's bash tool. Deliberately smaller than agent-ws —
  # talos v1 is a chat/agent service, not a full dev workspace; grow this as
  # the workspace grows.
  toolchain = with pkgs; [
    bash coreutils gnugrep gnused findutils
    git openssh jq curl ripgrep
    _1password-cli tea heph
  ];

  # op needs /etc/passwd and an owned HOME ([[lesson_op_and_pvc_in_container]]).
  etcFiles = pkgs.runCommand "talos-etc" { } ''
    mkdir -p $out/etc
    printf '%s\n' \
      'root:x:0:0::/root:${pkgs.bash}/bin/bash' \
      'talos:x:1500:1500::/home/talos:${pkgs.bash}/bin/bash' > $out/etc/passwd
    printf '%s\n' 'root:x:0:' 'talos:x:1500:' > $out/etc/group
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/talos";
  tag = "v${version}";

  contents = [ pkgs.bun app etcFiles entrypoint pkgs.dockerTools.caCertificates ] ++ toolchain;

  config = {
    Cmd = [ "${entrypoint}/bin/talos-entrypoint" ];
    Env = [
      "PATH=${lib.makeBinPath ([ pkgs.bun entrypoint ] ++ toolchain)}"
      "TALOS_HOST=0.0.0.0"
    ];
    ExposedPorts = { "3000/tcp" = { }; };
    User = "1500:1500";
    WorkingDir = "/app";
  };
}
