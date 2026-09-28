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
      sha256 = "cmToFA0n7GPKegwtvhOWvLU7u3hQd3M3z1auC8zT6EA=";
    };
    unpackCmd = "tar xzf $curSrc";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cp pulumi $out/bin/pulumi
    '';
    dontStrip = true;
  };

  # Each Pulumi project's Pulumi.yaml, baked to /projects/<projdir>/Pulumi.yaml.
  # `pulumi config` (unlike `stack export`) refuses to run without a Pulumi.yaml
  # in the working tree, so the cronjob calls it with --cwd /projects/<projdir>;
  # the project name inside must match the --stack project segment
  # (blumeops-tailnet / blumeops-dns). One derivation per project — stdenv's
  # multi-src unpack trips on a top-level dir, and a bare `cp Pulumi.yaml`
  # (basename) is what resolves once the single src root is unpacked.
  projFile = pname: srcdir: pkgs.stdenv.mkDerivation {
    pname = "pulumi-project-${pname}";
    version = "unstable";
    src = srcdir;
    installPhase = ''
      mkdir -p $out/projects/${pname}
      cp Pulumi.yaml $out/projects/${pname}/Pulumi.yaml
    '';
  };
  projTailscale = projFile "tailscale" ../../pulumi/tailscale;
  projGandi = projFile "gandi" ../../pulumi/gandi;
in

assert pkgs.pulumi-bin.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/pulumi-stack-backup";

  contents = [
    pulumi
    projTailscale
    projGandi
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gnutar
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
