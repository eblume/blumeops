# Centralized version and source pinning for authentik 2026.2.2
# All sources fetched from forge mirrors for supply chain control
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2026.2.2";
in
{
  inherit version;

  # Main authentik repo — provides schema.yml, Python backend, web UI, Go server
  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik.git";
    rev = "version/${version}";
    hash = "sha256-Xq7JGI/8ppIydIuWd9KRJKUrh7UpeniwvZ4NAtXbYJ4=";
  };

  # Go API client repo — provides config.yaml, go.mod, go.sum, templates
  client-go-src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/authentik-client-go.git";
    rev = "v3.2026.2.1";
    hash = "sha256-sFj+KAFHe3ajOFUtfBl9X3AVIvMCO8+Xba+/Jsy7Cgo=";
  };

  meta = with pkgs.lib; {
    description = "Authentik identity provider";
    homepage = "https://goauthentik.io";
    license = licenses.mit;
  };
}
