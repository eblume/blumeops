# Nix-built Pulumi CLI image for the pulumi-stack-backup CronJob on ringtail
# (amd64). Backs up Pulumi Cloud stack state (`pulumi stack export --show-secrets`
# + `pulumi config --show-secrets`) so losing the Pulumi Cloud account or a stack
# does not mean re-importing every Tailscale and Gandi resource by hand
# (eblume/blumeops#1300). See docs/how-to/pulumi/restore-pulumi-state.md for the
# restore runbook.
#
# Built as its own derivation rather than pkgs.pulumi-bin so the asset hash is
# checked in here; nixpkgs' 3.237.0 trails the mise pin — fine for
# `stack export`/`config` (import only requires CLI >= checkpoint writer).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.237.0";

  pulumi = pkgs.stdenv.mkDerivation {
    pname = "pulumi-cli";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://get.pulumi.com/releases/sdk/pulumi-v${version}-linux-x64.tar.gz";
      sha256 = "0z50j7zzd22qcizmd6w3j2vzap0hp3k48w218lqrga0lvmkfw5ls";
    };
    unpackCmd = "tar xzf $curSrc";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cp pulumi/pulumi $out/bin/pulumi
    '';
    dontStrip = true;
  };
in

assert pkgs.pulumi-bin.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/pulumi-stack-backup";

  contents = [
    pulumi
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.tar
    pkgs.curl
    pkgs.cacert
  ];

  config = {
    Cmd = [ "${pulumi}/bin/pulumi" "version" ];
    Env = [
      "HOME=/tmp"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PULUMI_SKIP_UPDATE_CHECK=1"
      "PULUMI_HOME=/var/empty"
    ];
    User = "65534";
  };
}
