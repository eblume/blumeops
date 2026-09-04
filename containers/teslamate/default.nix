# Nix-built TeslaMate for ringtail (amd64).
#
# Replaces the Dagger container.py (Elixir+Node builder -> Debian slim).
# TeslaMate is NOT in nixpkgs, so this is a from-scratch beamPackages
# mixRelease: an Elixir/Phoenix release with npm-built assets.
#
# Pinned to the same nixos-unstable rev as paperless/mealie for a
# consistent toolchain. The BEAM combo is pinned to erlang_27 + elixir_1_18
# (teslamate requires elixir ~> 1.17; upstream's image uses OTP 26, so we
# stay off the default OTP 28 which elixir 1.18 does not target).
#
# Source comes from the forge mirror (supply-chain control), pinned by the
# v3.0.0 tag's commit so builtins.fetchGit needs no hash.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/331800de5053fcebacf6813adb5db9c9dca22a0c.tar.gz";
    sha256 = "1p54fm6dkbq62kpi55cr4wyx7b1nsajpsnjgs64cmp073fwi15f7";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  lib = pkgs.lib;

  version = "3.0.0";

  beamPackages = pkgs.beam.packages.erlang_27;
  elixir = beamPackages.elixir_1_18;

  src = builtins.fetchGit {
    url = "https://forge.ops.eblu.me/mirrors/teslamate.git";
    ref = "refs/tags/v${version}";
    rev = "3281154d42330786a182c1bbe094ecda0b1c5578";
  };

  # ex_cldr downloads locale JSON from GitHub at compile time, which the
  # build sandbox blocks. teslamate's cldr.ex reads the data dir from the
  # LOCALES env var; point it at the pre-fetched elixir-cldr data so no
  # download is attempted (with SKIP_LOCALE_DOWNLOAD=true disabling the
  # forced refresh). CLDR data version matches the compile-time errors.
  cldrData = pkgs.fetchFromGitHub {
    owner = "elixir-cldr";
    repo = "cldr";
    rev = "v2.46.0";
    sha256 = "1iwzk9dc754l72vpf8vsisdjncnjx26pz509552b6vnm49xbxyji";
  };

  teslamate = beamPackages.mixRelease {
    pname = "teslamate";
    inherit version src elixir;

    # Keep the build-generated Erlang cookie in the release. mixRelease
    # strips it by default (expecting RELEASE_COOKIE at runtime), but the
    # start script reads releases/COOKIE. teslamate is single-node (no
    # distributed Erlang exposed), so a baked-in cookie is fine.
    removeCookie = false;

    mixFodDeps = beamPackages.fetchMixDeps {
      pname = "mix-deps-teslamate";
      inherit src version elixir;
      hash = "sha256-DDrREiM1BIMgD2qFPTK8QyjOYlnfE3XlnaH/jk7G2go=";
    };

    # Frontend assets. esbuild + sass are devDeps and the esbuild platform
    # binary is an optional dep, so npm ci must include both. We run npm ci
    # here (not a separate derivation) because assets/package.json has
    # file:../deps/phoenix references that only resolve once mixFodDeps has
    # populated deps/. npmConfigHook wires up the offline cache from npmDeps;
    # then `node scripts/build.js` (custom esbuild) + `mix phx.digest`.
    nativeBuildInputs = [ pkgs.nodejs pkgs.npmHooks.npmConfigHook ];
    npmDeps = pkgs.fetchNpmDeps {
      name = "teslamate-npm-deps";
      src = src + "/assets";
      hash = "sha256-XyiaUkT/c4rZnNxmxhVLb+vEXnc64A1hjOrnR5fhaEk=";
    };
    npmRoot = "assets";

    preBuild = ''
      export SKIP_LOCALE_DOWNLOAD=true
      export LOCALES=${cldrData}/priv/cldr
      ( cd assets && npm ci --include=dev --include=optional && node scripts/build.js )
      mix phx.digest --no-deps-check
    '';
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/teslamate";

  contents = [
    teslamate
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.dash
    pkgs.netcat-openbsd
    pkgs.cacert
    pkgs.tzdata
  ];

  # /opt/app (HOME, SRTM_CACHE) and /tmp must be writable by the runtime
  # uid 1000; the build user can't chown, so ownership is set in
  # fakeRootCommands (fakeroot records it into the layer tar).
  extraCommands = ''
    mkdir -p opt/app/.srtm_cache tmp
    chmod 1777 tmp
  '';
  fakeRootCommands = ''
    chown -R 1000:1000 opt/app
  '';
  enableFakechroot = true;

  config = {
    # Mirror entrypoint.sh: wait for postgres, run migrations, then start.
    Entrypoint = [
      "${pkgs.dash}/bin/dash"
      "-c"
      ''
        : "''${DATABASE_HOST:=127.0.0.1}"
        : "''${DATABASE_PORT:=5432}"
        while ! ${pkgs.netcat-openbsd}/bin/nc -z "$DATABASE_HOST" "$DATABASE_PORT" 2>/dev/null; do
          echo "waiting for postgres at $DATABASE_HOST:$DATABASE_PORT"; sleep 1
        done
        ${teslamate}/bin/teslamate eval "TeslaMate.Release.migrate"
        exec ${teslamate}/bin/teslamate start
      ''
    ];
    Env = [
      "HOME=/opt/app"
      "SRTM_CACHE=/opt/app/.srtm_cache"
      "LANG=C.UTF-8"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    ExposedPorts = {
      "4000/tcp" = { };
    };
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
