# Nix-built ntfy push notification server
# Builds v2.24.0 from forge mirror
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.24.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/ntfy.git";
    rev = "v${version}";
    hash = "sha256-ca04r8kMSAqWiEN6F36n75hy46Alb21UUtQ1/mwpQcY=";
  };

  ui = pkgs.buildNpmPackage {
    inherit src version;
    pname = "ntfy-sh-ui";
    npmDepsHash = "sha256-ASh88vfDrR+uf4IFOjj/SK2Hb+gwSNuKQwTGYBTogXo=";

    prePatch = ''
      cd web/
    '';

    installPhase = ''
      runHook preInstall
      mv build/index.html build/app.html
      rm build/config.js
      mkdir -p $out
      mv build/ $out/site
      runHook postInstall
    '';
  };

  ntfy = pkgs.buildGoModule {
    inherit src version;
    pname = "ntfy-sh";
    vendorHash = "sha256-9xrqa/eDpyzeLBMM31Q8CsRhdATB2DYkOoE/CxycgzY=";

    doCheck = false;

    subPackages = [ "." ];

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];

    postPatch = ''
      sed -i 's# /bin/echo# echo#' Makefile
    '';

    # Copy pre-built web UI; skip docs (create placeholder for go:embed)
    preBuild = ''
      cp -r ${ui}/site/ server/
      mkdir -p server/docs && touch server/docs/placeholder
    '';

    meta = with pkgs.lib; {
      description = "Send push notifications to your phone or desktop via PUT/POST";
      homepage = "https://ntfy.sh";
      license = licenses.asl20;
      mainProgram = "ntfy";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/ntfy";
  contents = [
    ntfy
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${ntfy}/bin/ntfy" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "80/tcp" = { };
    };
    User = "65534";
  };
}
