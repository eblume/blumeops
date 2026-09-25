# Nix-built External Secrets Operator for ringtail k3s: the forge mirror
# compiled with all secret providers, faithful to upstream's `make build`
# (-tags all_providers).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.11.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/external-secrets.git";
    rev = "v${version}";
    hash = "sha256-QndmhH8xIyVCKuK7KP0Qeuxnuz8bEx7h+FxwZSWJaU8=";
  };

  # external-secrets v2.11.0 requires Go >= 1.26.6.
  external-secrets = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "external-secrets";
    vendorHash = "sha256-abESbAaCV2R4DSq86n01LJlFxLmwJibn28pN6fUzJg4=";

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
