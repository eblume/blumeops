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
# Version note: the build host resolves <nixpkgs> to the nixos-26.05 pin,
# which lags prowler — newer releases only exist on nixos-unstable, so this
# self-pins an unstable rev instead (miniflux/mealie/navidrome precedent).
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0bb2eedc20e4739f29e8045034f2828ad7054f8f.tar.gz";
    sha256 = "008j4dj5yrzww91qvp1lp2c9d1lkwc6i2dpainf5nkdkr3rwj8vy";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "5.47.0";
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
