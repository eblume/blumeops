# Warrant — approval broker for agent-requested privileged runs.
# v0.1 scaffold: request queue + read-only UI, NO approval path and NO
# privileged credentials (see app/main.py and [[warrant-approval-gated-runs]]).
#
# App source is vendored in ./app (no wheel/PyPI round-trip — it's a small
# single-file FastAPI service); deps come from nixpkgs python packages, so
# the build is fully offline. Builds on the nix-container-builder runner.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.2.0";

  python = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    pyjwt
    cryptography
    python-multipart  # UI decision forms (v0.2b)
  ]);

  appDir = pkgs.runCommand "warrant-app" { } ''
    mkdir -p $out/app
    cp ${./app/main.py} $out/app/main.py
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/warrant";
  tag = "v${version}";

  contents = [ python appDir pkgs.dockerTools.caCertificates ];

  config = {
    Cmd = [
      "${python}/bin/python" "-m" "uvicorn" "main:app"
      "--host" "0.0.0.0" "--port" "8080" "--app-dir" "/app"
    ];
    Env = [
      "WARRANT_DB=/data/warrant.db"
      "PYTHONUNBUFFERED=1"
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    User = "1500:1500";
    WorkingDir = "/app";
  };
}
