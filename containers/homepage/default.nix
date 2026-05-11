# Nix-built gethomepage/homepage dashboard
# Builds v1.11.0 from forge mirror.
#
# Adapted from nixpkgs pkgs/by-name/ho/homepage-dashboard (commit master),
# changed to fetch from our forge mirror and wrap with dockerTools for an
# amd64 image runnable on ringtail's k3s.
#
# The preBuild substitutions are not optional — without them Next.js writes
# its file-system-cache to a read-only path and prerender state breaks after
# restart (nixpkgs issues #328621 and #458494).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.11.0";

  homepage = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "homepage-dashboard";
    inherit version;

    src = pkgs.fetchgit {
      url = "https://forge.ops.eblu.me/mirrors/homepage.git";
      rev = "v${version}";
      hash = "sha256-jnv9PnClm/jIQ4uU6c4A1UiAmwoihG0l6k3fUbD47I4=";
    };

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      pnpm = pkgs.pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-X5j9XppbcasGuC7fUsj4XzbaQFM9WcRcXjgJHN/inR8=";
    };

    nativeBuildInputs = [
      pkgs.makeBinaryWrapper
      pkgs.nodejs_24
      pkgs.pnpmConfigHook
      pkgs.pnpm_10
    ];

    buildInputs = [
      pkgs.nodePackages.node-gyp-build
    ];

    env.PYTHON = "${pkgs.python3}/bin/python";

    preBuild = ''
      substituteInPlace node_modules/next/dist/server/lib/incremental-cache/file-system-cache.js \
        --replace-fail 'this.serverDistDir = ctx.serverDistDir;' \
                       'this.serverDistDir = require("path").join((process.env.NIXPKGS_HOMEPAGE_CACHE_DIR || "/tmp/homepage-cache"), "homepage");'

      for bundle in node_modules/next/dist/compiled/next-server/*.runtime.prod.js; do
        substituteInPlace "$bundle" \
          --replace-fail 'this.serverDistDir=e.serverDistDir' \
                         'this.serverDistDir=(process.env.NIXPKGS_HOMEPAGE_CACHE_DIR||"/tmp/homepage-cache")+"/homepage"'
      done
    '';

    buildPhase = ''
      runHook preBuild
      mkdir -p config
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/{bin,share}
      cp -r .next/standalone $out/share/homepage/
      cp -r public $out/share/homepage/public
      chmod +x $out/share/homepage/server.js

      mkdir -p $out/share/homepage/.next
      cp -r .next/static $out/share/homepage/.next/static

      makeWrapper "${pkgs.lib.getExe pkgs.nodejs_24}" $out/bin/homepage \
        --set-default PORT 3000 \
        --set-default HOMEPAGE_CONFIG_DIR /app/config \
        --set-default NIXPKGS_HOMEPAGE_CACHE_DIR /tmp/homepage-cache \
        --add-flags "$out/share/homepage/server.js" \
        --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.unixtools.ping ]}"

      runHook postInstall
    '';

    doDist = false;
  });
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/homepage";
  contents = [
    homepage
    pkgs.cacert
    pkgs.tzdata
  ];

  extraCommands = ''
    mkdir -p tmp
    chmod 1777 tmp
  '';

  # /app/config must be writable by the runtime user (1000): homepage seeds
  # missing skeleton configs (proxmox.yaml, etc.) and writes /app/config/logs.
  # The deployment mounts ConfigMap files at /app/config/<file>.yaml via
  # subPath, which leaves the parent dir as image filesystem — so its
  # ownership has to be set at build time.
  fakeRootCommands = ''
    mkdir -p app/config
    chown -R 1000:1000 app
  '';
  enableFakechroot = true;

  config = {
    Entrypoint = [ "${homepage}/bin/homepage" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "TMPDIR=/tmp"
      "NIXPKGS_HOMEPAGE_CACHE_DIR=/tmp/homepage-cache"
      "HOMEPAGE_CONFIG_DIR=/app/config"
      "NEXT_TELEMETRY_DISABLED=1"
      "PORT=3000"
    ];
    ExposedPorts = {
      "3000/tcp" = { };
    };
    User = "1000";
  };
}
