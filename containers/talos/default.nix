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

  version = "0.1.3";
  rev = "54671868996108ea9078b29720f1dadde7291a12";

  src = pkgs.fetchgit {
    url = "https://forge.eblu.me/eblume/talos.git";
    inherit rev;
    hash = "sha256-mfMzJ4EXbkrDKuWWOZsz6RUdFSJO2SUiPxRSsANMi0A=";
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

  # Toolchain for the agent's bash tool. Deliberately smaller than agent-ws —
  # talos v1 is a chat/agent service, not a full dev workspace; grow this as
  # the workspace grows.
  toolchain = with pkgs; [
    bash coreutils gnugrep gnused findutils
    git openssh jq curl ripgrep
    _1password-cli
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

  contents = [ pkgs.bun app etcFiles pkgs.dockerTools.caCertificates ] ++ toolchain;

  config = {
    Cmd = [ "${pkgs.bun}/bin/bun" "run" "/app/src/server.ts" ];
    Env = [
      "PATH=${lib.makeBinPath ([ pkgs.bun ] ++ toolchain)}"
      "TALOS_HOST=0.0.0.0"
    ];
    ExposedPorts = { "3000/tcp" = { }; };
    User = "1500:1500";
    WorkingDir = "/app";
  };
}
