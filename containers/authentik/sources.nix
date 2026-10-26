# Centralized version and source pinning for authentik 2026.5.8
# All sources fetched from forge mirrors for supply chain control
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2026.5.8";
in
{
  inherit version;

  # Main authentik repo — provides schema.yml, Python backend, web UI, Go server
  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik.git";
    rev = "version/${version}";
    hash = "sha256-g4TurRSLMarStJLV4QWpccyKfoXfkOqOQbLDlnlwUqU=";
  };

  meta = with pkgs.lib; {
    description = "Authentik identity provider";
    homepage = "https://goauthentik.io";
    license = licenses.mit;
  };
}
