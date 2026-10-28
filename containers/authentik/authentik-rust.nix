{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
}:

pkgs.rustPlatform.buildRustPackage {
  pname = "authentik-rust";
  inherit (sources) version src meta;

  # TOFU: the PR build fills this (fakeHash round); a cargoLock.lockFile read
  # would be import-from-derivation at eval.
  cargoHash = "sha256-0rAUylZu/CD3B4nysNhOy8Fqtw29LWphW1UZ5LuwckQ=";

  cargoBuildFlags = [ "--package" "authentik" "--no-default-features" "--features" "core" ];
  doCheck = false;

  nativeBuildInputs = with pkgs; [
    cmake
    clang
    go
    perl
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [ pkgs.python314 ];

  # aws-lc-fips-sys needs clang (as the upstream Dockerfile sets)
  AWS_LC_FIPS_SYS_CC = "clang";
  # pyo3 links against libpython
  PYO3_PYTHON = "${pkgs.python314}/bin/python3.14";
}
