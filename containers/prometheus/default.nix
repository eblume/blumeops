# Nix-built Prometheus for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build (v3.14.0 from the forge mirror,
# same ldflags). The web UI is a pnpm workspace (prometheus migrated from npm
# at v3.13.0): fetchPnpmDeps pins the dependency store, the legacy React app
# is disabled with nixpkgs' patch (it isn't served by Prometheus 3.x), the
# Go build embeds the gzipped assets via a generated embed.go with the
# builtinassets tag (the compress_assets.sh equivalent).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.14.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/prometheus.git";
    rev = "v${version}";
    hash = "sha256-7PSfh+KWUpmL3BZ7INa1DOZ/ysaXXdWG9n/F+H0cGYo=";
  };

  assets = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "prometheus-assets";
    inherit version;

    src = "${src}/web/ui";

    patches = [ ./disable-react-app.diff ];

    nativeBuildInputs = [
      pkgs.gzip
      pkgs.nodejs_22
      pkgs.pnpm_10
      pkgs.pnpmConfigHook
    ];

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version;
      src = "${src}/web/ui";
      pnpm = pkgs.pnpm_10;
      pnpmWorkspaces = [
        "@prometheus-io/mantine-ui"
        "@prometheus-io/codemirror-promql"
        "@prometheus-io/lezer-promql"
      ];
      # TOFU: filled from the pod build (fakeHash round).
      hash = "sha256-5ywjd7Vck5oqogXxn4/wOtwtgM7dulvxedXjvF29uCk=";
      fetcherVersion = 3;
    };

    env.CI = true;
    doCheck = false;

    buildPhase = ''
      runHook preBuild
      bash ./build_ui.sh --all
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/static
      cp -r ./static/* $out/static/
      find $out/static -type f -exec gzip -f9 {} \;
      runHook postInstall
    '';
  });

  prometheus = pkgs.buildGoModule {
    inherit src version;
    pname = "prometheus";
    vendorHash = "sha256-sCgxO2/w3Bi6Ncs/Q+JVZVtQC448FEx3llYxe/UxWEE=";
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
