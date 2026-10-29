# Centralized version and source pinning for authentik 2026.8.5
# All sources fetched from forge mirrors for supply chain control
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2026.8.5";
in
{
  inherit version;

  # Main authentik repo — provides schema.yml, Python backend, web UI, Go server
  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik.git";
    rev = "version/${version}";
    hash = "sha256-gdhGKCfsMUrWyFnf5TaaHM2ZQ1WYgTLOgGg4DlCaUHU=";
  };

  meta = with pkgs.lib; {
    description = "Authentik identity provider";
    homepage = "https://goauthentik.io";
    license = licenses.mit;
  };
}
