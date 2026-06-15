# Nix-built kube-state-metrics
# Builds v2.19.1 from forge mirror
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.19.1";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/kube-state-metrics.git";
    rev = "v${version}";
    hash = "sha256-PZC3ZiVnChy7IdibZKB3IRv8+1AfmvAWY7RquwTcS1Y=";
  };

  kube-state-metrics = pkgs.buildGoModule {
    inherit src version;
    pname = "kube-state-metrics";
    vendorHash = "sha256-vmmXEDzkv+ZQaKJ6++HpPHj2M9gaquonNjXG2DOlxwI=";

    doCheck = false;

    subPackages = [ "." ];

    ldflags = [
      "-s"
      "-w"
      "-X k8s.io/kube-state-metrics/v2/pkg/version.Version=v${version}"
    ];

    meta = with pkgs.lib; {
      description = "Generates metrics about the state of Kubernetes objects";
      homepage = "https://github.com/kubernetes/kube-state-metrics";
      license = licenses.asl20;
      mainProgram = "kube-state-metrics";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/kube-state-metrics";
  contents = [
    kube-state-metrics
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${kube-state-metrics}/bin/kube-state-metrics" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
      "8081/tcp" = { };
    };
    User = "65534";
  };
}
