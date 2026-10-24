# Green: a dotted reference in a data attr is Nix data, not shell. `pnpm`
# holds a derivation, so `pkgs.pnpm_10` is gradable and green - only attrs
# that run as shell make a dotted reference ungradable.
pkgs.fetchPnpmDeps {
  pname = "x";
  version = "1.0";
  src = ./src;
  hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  pnpm = pkgs.pnpm_10;
  fetcherVersion = 3;
}
