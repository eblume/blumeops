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
# `version` is the image-tag version: bump it for an upstream talos bump
# (update `rev` + `srcHash`, and `npmDepsHash` if the lockfile changed) OR for
# a meaningful change to the baked toolchain, then
# `mise run container-release talos <version>`.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  # allowUnfree: the 1Password CLI (_1password-cli) is unfree.
  pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  lib = pkgs.lib;

  version = "0.2.8";
  rev = "3995a5a0336423e49120a968d0b6bdada2e57088";

  src = pkgs.fetchgit {
    url = "https://forge.eblu.me/eblume/talos.git";
    inherit rev;
    hash = "sha256-7ar2CshHyP09BjQidh2tsGaHKk06hMpztfDxtrIl5oA=";
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
    npmDepsHash = "sha256-lpcFgjzSIeZf2LiXp5Gdy6r0EX2uGwoPZ3IgFQZaNmM=";
    dontNpmBuild = true;
    npmFlags = [ "--ignore-scripts" ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/app
      cp -r node_modules src public package.json $out/app/
      runHook postInstall
    '';
  };

  # The repo pool — /repos.json at the repo root is THE source of truth for
  # what the agents bot may touch ([[agents-forgejo-bot]]). Shared with
  # agent-ws; the file is org-level agent policy, not container config.
  repoPolicy = builtins.fromJSON (builtins.readFile ../../repos.json);
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

    # The workspace's mise.toml/mise-tasks are trusted without a prompt —
    # there is no terminal in this pod to answer one.
    export MISE_TRUSTED_CONFIG_PATHS="$code"
    # Dynamic-loader path for prebuilt binaries (mise's rust); see ldLibs.
    export LD_LIBRARY_PATH="${lib.makeLibraryPath ldLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # nix's store lives at the canonical /nix/store on the container's
    # writable layer, which is fresh at every pod start — nothing to sweep.
    # Within a pod's life, build outputs are reclaimed by `nix store gc`
    # (no GC roots exist in the pod; see default.nix).

    exec ${pkgs.bun}/bin/bun run /app/src/server.ts
  '';

  # Toolchain for the agent's bash tool. Deliberately smaller than agent-ws —
  # talos is a chat/agent service, not a full dev workspace; grow this as the
  # workspace grows.
  #
  # mise + uv + python3 earn their place because the repo's privileged-run
  # path (`mise run request-run …`, [[warrant-approval-gated-runs]]) is a
  # mise task whose script is `#!/usr/bin/env -S uv run --script`: without
  # all three the agent hand-installed uv into the pod to file a warrant
  # request (2026-08-15). python3 must be ON PATH — uv otherwise downloads
  # its own CPython, whose glibc loader does not run in this non-FHS image.
  # gnutar/gzip are what uv and mise unpack with; which is what _require
  # guards reach for.
  toolchain = with pkgs; [
    bash coreutils gnugrep gnused findutils
    git openssh jq curl ripgrep
    _1password-cli teaWrapper heph
    mise uv python3 gnutar gzip which
    nix
  ];

  # tea, wrapped to route through the tag:agent SOCKS sidecar. tea only ever
  # contacts the forge (forge.ops.eblu.me), which the pod can reach ONLY via
  # the proxy, and tea (unlike git) has no per-URL proxy config — so send all
  # of tea's traffic through the proxy. A GLOBAL proxy would be wrong (it'd
  # break op↔1Password and the server↔OpenRouter, which must egress
  # directly), hence a tea-specific wrapper. Shadows pkgs.tea on PATH
  # (agent-ws precedent). Without it, `tea pr create` from the pod dies with
  # "connection refused" (2026-08-15).
  teaWrapper = pkgs.writeShellScriptBin "tea" ''
    export HTTPS_PROXY="socks5h://localhost:1055"
    export HTTP_PROXY="socks5h://localhost:1055"
    exec ${pkgs.tea}/bin/tea "$@"
  '';

  # Runtime libs for prebuilt dynamically-linked binaries (mise's rust),
  # resolved via the /lib64 loader symlink in extraCommands — the container
  # analogue of nix-ld (agent-ws precedent).
  ldLibs = with pkgs; [ glibc stdenv.cc.cc.lib zlib ];

  # ── nix, real builds in the pod ──────────────────────────────────────────
  # /nix/store and /nix/var are chowned to uid 1500 in the image (see
  # fakeRootCommands below), so nix builds against the canonical store and
  # substitutes from cache.nixos.org. sandbox = false because seccomp refuses
  # CLONE_NEWUSER; the pod's existing fences are the boundary. Full argument:
  # [[agent-containerization]] §"Nix in the pod".
  nixConfDir = pkgs.writeTextDir "nix.conf" ''
    experimental-features = nix-command flakes
    # Matches the Deployment's CPU limit so a build cannot out-eat the node.
    max-jobs = 2
    # No CLONE_NEWUSER in this pod — nix could not set the sandbox up anyway.
    sandbox = false
    warn-dirty = false
  '';

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

  # Non-FHS fixups (agent-ws precedent): /usr/bin/env because every
  # mise-tasks script uses a `#!/usr/bin/env -S …` shebang and the kernel
  # resolves it literally; a /tmp because dockerTools images have none and
  # half of userspace (uv, pytest, curl -o) assumes it; the glibc loader at
  # its conventional path so prebuilt ELF binaries (mise) run — see ldLibs.
  extraCommands = ''
    mkdir -p lib64 tmp usr/bin
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    ln -s ${pkgs.coreutils}/bin/env usr/bin/env
    chmod 1777 tmp
  '';

  # Make the canonical store writable by uid 1500 without hiding lower-layer content.
  fakeRootCommands = ''
    mkdir -p nix/store nix/var
    chown -R 1500:1500 nix
  '';

  config = {
    Cmd = [ "${entrypoint}/bin/talos-entrypoint" ];
    Env = [
      "PATH=${lib.makeBinPath ([ pkgs.bun entrypoint ] ++ toolchain)}"
      "TALOS_HOST=0.0.0.0"
      # nix config baked into the image (see the nix block above). Set here
      # rather than in the entrypoint so it holds for every way into the
      # container (kubectl exec included).
      "NIX_CONF_DIR=${nixConfDir}"
      # nix's fetchers speak TLS to the forge/GitHub — point them at a bundle.
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    ExposedPorts = { "3000/tcp" = { }; };
    User = "1500:1500";
    WorkingDir = "/app";
  };
}
