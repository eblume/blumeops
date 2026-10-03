# Nix-built tailscale k8s-operator for ringtail's tailscale-operator app.
# Builds cmd/k8s-operator v1.98.5 from the forge mirror, mirroring upstream's
# build_docker.sh mkctr recipe (binary at /usr/local/bin/operator, ts_kube +
# ts_package_container go tags). Built on the ringtail nix-container-builder.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.102.5";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/tailscale.git";
    rev = "v${version}";
    hash = "sha256-gm5NN4IqR7epks8WjncQBsPYaPsH+ooXporzpuCEac0=";
  };

  # go.mod floor is go >= 1.26.6; nixpkgs default Go (1.25.x) fails with
  # GOTOOLCHAIN=local, so pin go_1_26 explicitly (buildGoModule toolchain floor).
  operator = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "tailscale-operator";
    vendorHash = "sha256-amKkUPszyhG4N5ZtrB01swBACYq76raSS+SQRneLmwc=";

    subPackages = [ "cmd/k8s-operator" ];

    tags = [
      "ts_kube"
      "ts_package_container"
    ];

    ldflags = [
      "-s"
      "-w"
      "-X tailscale.com/version.longStamp=${version}"
      "-X tailscale.com/version.shortStamp=${version}"
    ];

    doCheck = false;

    meta = with pkgs.lib; {
      description = "Tailscale operator for Kubernetes";
      homepage = "https://tailscale.com";
      license = licenses.bsd3;
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/tailscale-operator";
  tag = "v${version}";

  contents = [
    operator
    pkgs.cacert
  ];

  # buildGoModule names the binary after the package dir (k8s-operator);
  # upstream's image expects /usr/local/bin/operator.
  extraCommands = ''
    mkdir -p usr/local/bin
    ln -s /bin/k8s-operator usr/local/bin/operator
  '';

  config = {
    Entrypoint = [ "/usr/local/bin/operator" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
