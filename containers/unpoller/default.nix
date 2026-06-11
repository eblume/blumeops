# Nix-built UnPoller for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# nixpkgs' unpoller lags badly (2.15.4 vs our v3.2.0), so this builds from
# the forge mirror at the pinned tag — the ntfy pattern. Same ldflags as
# the Dagger build (golift.io/version stamps).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.2.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/unpoller.git";
    rev = "v${version}";
    hash = "sha256-EbM+/7zlGGytygeKVgkhC5jC5QMWi/bKkq4tDtJmGHk=";
  };

  unpoller = pkgs.buildGoModule {
    inherit src version;
    pname = "unpoller";
    vendorHash = "sha256-Xnu5T1M0fjWVz3LsIXXYjuAFeo/t8URJutH6QS3pQhk=";

    doCheck = false;
    subPackages = [ "." ];

    ldflags = [
      "-s"
      "-w"
      "-X main.version=v${version}"
      "-X main.builtBy=blumeops"
      "-X golift.io/version.Version=v${version}"
      "-X golift.io/version.Branch=HEAD"
      "-X golift.io/version.BuildUser=blumeops"
      "-X golift.io/version.Revision=blumeops-build"
    ];

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
