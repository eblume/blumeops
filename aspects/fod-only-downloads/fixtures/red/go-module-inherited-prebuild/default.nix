# Red fixture: the buildGoModule vendor FOD inherits preBuild - a hook
# like `go generate ./...` runs over the downloaded source with network.
# Clear it in the FOD with overrideModAttrs.preBuild = "" like
# containers/ntfy and containers/prometheus do (eblume/blumeops#1809).
{ pkgs ? import <nixpkgs> { } }:

pkgs.buildGoModule {
  pname = "evil-module";
  version = "1.0";
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  vendorHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";

  preBuild = ''
    go generate ./...
  '';
}
