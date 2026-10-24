# Green fixture: the vendor FOD's inherited hooks cleared via
# overrideModAttrs - the pattern containers/ntfy and containers/prometheus
# use (eblume/blumeops#1850). The main build's own hooks are not FOD
# strings and stay.
{ pkgs ? import <nixpkgs> { } }:

let
  ui = pkgs.buildNpmPackage {
    pname = "thing-ui";
    version = "1.0";
    src = pkgs.fetchgit {
      url = "https://example.com/thing.git";
      rev = "v1.0";
      hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
    };
    npmDepsHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
    prePatch = ''
      cd web/
    '';
    installPhase = ''
      mv build/ $out/site
    '';
  };
in
pkgs.buildGoModule {
  pname = "thing";
  version = "1.0";
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  vendorHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";

  doCheck = false;

  postPatch = ''
    sed -i 's/old/new/' Makefile
  '';

  preBuild = ''
    cp -r ${ui}/site/ server/
  '';

  overrideModAttrs.preBuild = "";
  overrideModAttrs.postPatch = "";
}
