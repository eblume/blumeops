{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
}:

let
  # rust-toolchain.toml pins 1.97.1; the default nixpkgs rustc is 1.95.
  rustPlatform = pkgs.rustPackages_1_97.rustPlatform;
in

rustPlatform.buildRustPackage {
  pname = "authentik-rust";
  inherit (sources) version src meta;

  # A cargoLock.lockFile read would be import-from-derivation at eval.
  cargoHash = "sha256-dRsfsMH36xICg3WimQz3HX/Qgyt0dve/mvG7QERFzpo=";

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
  # tokio JoinSet::build_task is unstable-gated; upstream sets this via
  # .cargo/config.toml [build] rustflags, which the nixpkgs cargo hooks don't apply.
  RUSTFLAGS = "--cfg tokio_unstable";
}
