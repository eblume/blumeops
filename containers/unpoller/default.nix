# Nix-built UnPoller for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# nixpkgs' unpoller lags badly, so this builds from the forge mirror at the
# pinned tag — the ntfy pattern.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "5.2.5";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/unpoller.git";
    rev = "v${version}";
    hash = "sha256-5mIvcxBNn3DdYgDXzUJ5Czn+iua0zV4hhzaVPAG5NrA=";
  };

  # v5.2.5's go.mod requires go 1.26.0, above the channel's default Go, so
  # pin go_1_26 (1.26.7) to avoid a GOTOOLCHAIN=local build failure.
  unpoller = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "unpoller";
    vendorHash = "sha256-Op6Iz1weKQ8okkW7fR++PxiWLRDznLFqxWrEPNf1QeA=";

    doCheck = false;
    subPackages = [ "." ];

    ldflags = [ "-s" "-w" ];

    meta.mainProgram = "unpoller";
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/unpoller";

  contents = [
    unpoller
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Cmd = [ "${unpoller}/bin/unpoller" "--config" "/etc/unpoller/up.conf" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "9130/tcp" = { };
    };
    User = "65534";
  };
}
