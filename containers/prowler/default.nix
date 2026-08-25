# Nix-built Prowler for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Lift-and-shift of nixpkgs' prowler — the version assertion fails the
# build if a nixpkgs bump moves the package, so service-review drives
# re-bumps. Image/IaC scans (and the trivy they needed) were retired,
# so this ships the CLI only.
#
# python3+pyyaml is included for the cronjob's merge-mutelist
# initContainer (python3 -c "import yaml...").
#
# Version note: the build host resolves <nixpkgs> to ringtail's system
# flake pin (nixos-25.11), which is frozen at prowler 5.12.3 — and
# nixos-26.05 stable is too. 5.39.1 only exists on nixos-unstable, so
# this self-pins an unstable rev instead (miniflux/mealie/navidrome
# precedent; those pin 241313f4, which only carries 5.33.1, hence the
# newer rev here).
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ac6b2166e7a9375683b8e98f860f273222337b16.tar.gz";
    sha256 = "0k6m5apwzg36qkm3wil1pf4q0lv1hp7r2imx4nfz9bfssnk9gj5w";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "5.39.1";
  app = pkgs.prowler;

  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/prowler";

  contents = [
    app
    python
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Cmd = [ "${app}/bin/prowler" "--help" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "HOME=/tmp"
    ];
    User = "65534";
  };
}
