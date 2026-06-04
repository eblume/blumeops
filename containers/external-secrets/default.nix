# Nix-built External Secrets Operator (amd64, for ringtail k3s).
# Builds v2.2.0 from the forge mirror with all secret providers compiled in,
# faithful to upstream's `make build` (-tags all_providers). The container.py
# sibling builds the arm64 image for indri's minikube; this default.nix builds
# the amd64 image on ringtail's nix-container-builder.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.2.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/external-secrets.git";
    rev = "v${version}";
    hash = "sha256-eAocOAp5s4CFRrpKfQr2lf3Ji+6nQQ1A5/eTw5B7v9U=";
  };

  # external-secrets v2.2.0 requires Go >= 1.26.1; nixpkgs default go is 1.25.x.
  external-secrets = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "external-secrets";
    vendorHash = "sha256-0xuBK3fjAplPLAElHvKB6d+2lDz+De/s91fV4dPZwjE=";

    doCheck = false;

    subPackages = [ "." ];

    tags = [ "all_providers" ];

    ldflags = [ "-s" "-w" ];

    meta = with pkgs.lib; {
      description = "Kubernetes operator that integrates external secret management systems";
      homepage = "https://github.com/external-secrets/external-secrets";
      license = licenses.asl20;
      mainProgram = "external-secrets";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/external-secrets";
  contents = [
    external-secrets
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${external-secrets}/bin/external-secrets" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    User = "65534";
  };
}
