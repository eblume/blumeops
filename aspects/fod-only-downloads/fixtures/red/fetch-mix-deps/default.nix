# Red fixture: fetchMixDeps is a builder FOD - its build runs the mix
# dependency fetcher over the downloaded source. It has no no-execute
# mode: fetch each dependency with a no-execute fetcher instead (fetchHex,
# fetchurl, ...) per eblume/blumeops#1852.
{ pkgs ? import <nixpkgs> { } }:

pkgs.fetchMixDeps {
  name = "mix-deps";
  src = ./mix-project;
}
