# Nix-built Prometheus for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build (v3.14.0 from the forge mirror,
# same ldflags), using nixpkgs' two-derivation technique for the web UI:
# buildNpmPackage compiles the mantine UI workspaces (the legacy React
# app is disabled with nixpkgs' patch — it depends on the deprecated
# create-react-app and isn't served by Prometheus 3.x), the assets are
# gzipped, and the Go build embeds them via a generated embed.go with
# the builtinassets tag (the compress_assets.sh equivalent).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.14.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/prometheus.git";
    rev = "v${version}";
    hash = "sha256-7PSfh+KWUpmL3BZ7INa1DOZ/ysaXXdWG9n/F+H0cGYo=";
  };

  assets = pkgs.buildNpmPackage {
    pname = "prometheus-assets";
    inherit version;

    src = "${src}/web/ui";

    patches = [ ./disable-react-app.diff ];

    npmDepsHash = pkgs.lib.fakeHash;

    env.CI = true;
    doCheck = false;

    postInstall = ''
      mkdir -p $out/static
      cp -r $out/lib/node_modules/prometheus-io/static/* $out/static
      find $out/static -type f -exec gzip -f9 {} \;
      rm -rf $out/lib
    '';
  };

  prometheus = pkgs.buildGoModule {
    inherit src version;
    pname = "prometheus";
    vendorHash = pkgs.lib.fakeHash;
    proxyVendor = true;

    doCheck = false;
    subPackages = [
      "cmd/prometheus"
      "cmd/promtool"
    ];
    env.CGO_ENABLED = 0;
    tags = [
      "netgo"
      "builtinassets"
    ];

    postPatch = ''
      cp -r ${assets}/static web/ui/static
    '';

    # Recreate `make assets-compress`'s embed.go (nixpkgs technique)
    preBuild = ''
      cp web/ui/embed.go.tmpl web/ui/embed.go
      find web/ui/static -type f -name '*.gz' -print0 | sort -z | xargs -0 echo //go:embed >> web/ui/embed.go
      echo 'var EmbedFS embed.FS' >> web/ui/embed.go
      substituteInPlace web/ui/embed.go --replace-fail "web/ui/" ""
    '';

    ldflags = [
      "-s"
      "-w"
      "-X github.com/prometheus/common/version.Version=v${version}"
      "-X github.com/prometheus/common/version.Branch=HEAD"
      "-X github.com/prometheus/common/version.BuildUser=blumeops"
      "-X github.com/prometheus/common/version.Revision=blumeops-build"
    ];

    meta.mainProgram = "prometheus";
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/prometheus";

  contents = [
    prometheus
    pkgs.cacert
    pkgs.tzdata
  ];

  fakeRootCommands = ''
    mkdir -p ./prometheus ./etc/prometheus
    cp ${src}/documentation/examples/prometheus.yml ./etc/prometheus/prometheus.yml
    chown -R 65534:65534 ./prometheus ./etc/prometheus
  '';

  config = {
    Entrypoint = [ "${prometheus}/bin/prometheus" ];
    Cmd = [
      "--config.file=/etc/prometheus/prometheus.yml"
      "--storage.tsdb.path=/prometheus"
    ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "9090/tcp" = { };
    };
    Volumes = {
      "/prometheus" = { };
    };
    User = "65534";
  };
}
