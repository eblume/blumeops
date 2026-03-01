# Centralized version and source pinning for authentik 2026.2.0
# All sources fetched from forge mirrors for supply chain control
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2026.2.0";
in
{
  inherit version;

  # Main authentik repo — provides schema.yml, Python backend, web UI, Go server
  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik.git";
    rev = "version/${version}";
    hash = "sha256-pVQ34cZYX3hlk6hF1aZ/n32xMqTF4Jmp0G0VGDU7iXc=";
  };

  # Go API client repo — provides config.yaml, go.mod, go.sum, templates
  client-go-src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik-client-go.git";
    rev = "v3.${version}";
    hash = "sha256-DwXw/0QcSDYQKVhPA8tStrSoZooriQex/9FxSJtR/QY=";
  };

  meta = with pkgs.lib; {
    description = "Authentik identity provider";
    homepage = "https://goauthentik.io";
    license = licenses.mit;
  };
}
