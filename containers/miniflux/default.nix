# Nix-built Miniflux for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the from-source Dagger build (clone_from_forge + go_build) with
# nixpkgs' miniflux — a single static-ish Go binary with the web UI
# embedded, so this is the simplest possible wrap.
#
# Version note: ringtail's stable nixpkgs carries 2.3.1, a forward bump
# from the v2.2.19 Dockerfile build (mealie precedent: bump-with-review at
# migration). 2.3.0 adds a tombstone table / drops the `removed` entry
# status; RUN_MIGRATIONS=1 applies it on first boot. The minikube source
# database is never touched after the cutover dump, so rollback is "scale
# the minikube deployment back up against its own (pre-migration) DB".
# The version assertion makes nix-build fail if a pin bump changes the
# version unexpectedly.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.3.1";
  app = pkgs.miniflux;
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/miniflux";

  contents = [
    app
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.lib.getExe app}" ];
    Env = [
      "LISTEN_ADDR=0.0.0.0:8080"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
    };
    User = "65534";
  };
}
