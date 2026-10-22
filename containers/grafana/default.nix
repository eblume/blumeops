# Nix-built Grafana for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build, which already uses the official
# upstream release tarball (dl.grafana.com) rather than a source build —
# the kiwix-serve precedent. autoPatchelfHook rewires the dynamically
# linked binaries against the nix glibc. Layout matches the Dockerfile:
# /usr/share/grafana home, UID 472 (official image convention, PVC
# compatibility), dumb-init entrypoint.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "13.2.4";

  src = pkgs.fetchurl {
    url = "https://dl.grafana.com/oss/release/grafana-${version}.linux-amd64.tar.gz";
    hash = "sha256-xIdlmI/YhXJgfk6mcCUa+KjmSrPjYNDzz2em81h7kqs=";
  };

  grafanaDist = pkgs.stdenv.mkDerivation {
    pname = "grafana-dist";
    inherit version src;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/usr/share/grafana
      cp -a . $out/usr/share/grafana/
      runHook postInstall
    '';
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/grafana";

  contents = [
    grafanaDist
    pkgs.dumb-init
    pkgs.cacert
    pkgs.tzdata
  ];

  fakeRootCommands = ''
    mkdir -p ./etc/grafana ./var/lib/grafana ./var/log/grafana
    # 13.x datasources are gpx plugin processes that spawn per-plugin sockets
    # in /tmp; the pod's uid 472 cannot create /tmp itself, so the image must
    # carry one.
    mkdir -p ./tmp && chmod 1777 ./tmp
    cp ${grafanaDist}/usr/share/grafana/conf/defaults.ini ./etc/grafana/grafana.ini
    cp ${grafanaDist}/usr/share/grafana/conf/defaults.ini ./etc/grafana/defaults.ini
    chown -R 472:472 ./etc/grafana ./var/lib/grafana ./var/log/grafana
  '';

  config = {
    Entrypoint = [ "${pkgs.dumb-init}/bin/dumb-init" "--" ];
    # homepath is the REAL store path, not the /usr/share/grafana symlink
    # farm: grafana's core-plugin walker resolves symlinks and refuses
    # files that escape the plugin directory, crash-looping at startup.
    Cmd = [
      "${grafanaDist}/usr/share/grafana/bin/grafana"
      "server"
      "--homepath=${grafanaDist}/usr/share/grafana"
      "--config=/etc/grafana/grafana.ini"
      "cfg:default.paths.data=/var/lib/grafana"
      "cfg:default.paths.logs=/var/log/grafana"
      "cfg:default.paths.plugins=/var/lib/grafana/plugins"
      "cfg:default.paths.provisioning=/etc/grafana/provisioning"
    ];
    Env = [
      "PATH=${grafanaDist}/usr/share/grafana/bin:/usr/bin:/bin"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    WorkingDir = "${grafanaDist}/usr/share/grafana";
    ExposedPorts = {
      "3000/tcp" = { };
    };
    User = "472";
  };
}
