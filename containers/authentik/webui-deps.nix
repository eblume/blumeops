# Fixed-output derivation for authentik web UI pnpm dependencies
#
# Upstream web/ is a pnpm workspace (since 2026.8). fetchPnpmDeps fetches the
# whole workspace store with one hash; consumers (webui.nix) install from it
# offline with pnpmConfigHook. Same shape as containers/homepage and
# containers/prometheus.
#
# TOFU: hash is filled from the PR build's fakeHash round.
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

pkgs.fetchPnpmDeps {
  pname = "authentik-webui";
  inherit (sources) version src;
  sourceRoot = "${sources.src.name}/web";
  pnpm = pkgs.pnpm_11;
  fetcherVersion = 3;
  hash = pkgs.lib.fakeHash;
}
