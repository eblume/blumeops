# Nix-built nettest container
# Equivalent to the Dockerfile: curl, jq, bind (nslookup), ca-certs, bash
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  testScript = ./test-connectivity.sh;

  tools = pkgs.buildEnv {
    name = "nettest-tools";
    paths = [
      pkgs.curl
      pkgs.jq
      pkgs.dnsutils # provides nslookup, dig
      pkgs.cacert
      pkgs.coreutils
      pkgs.hostname
      pkgs.bashInteractive
    ];
  };
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/nettest";
  tag = "latest";

  contents = [ tools ];

  extraCommands = ''
    cp ${testScript} test-connectivity.sh
    chmod +x test-connectivity.sh
  '';

  config = {
    Entrypoint = [ "/bin/bash" "/test-connectivity.sh" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
