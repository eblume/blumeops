# Nix-built tailscale k8s-nameserver for ringtail's tailscale-operator DNSConfig.
# Builds cmd/k8s-nameserver v1.98.5 from the forge mirror, mirroring upstream's
# build_docker.sh mkctr recipe (binary at /usr/local/bin/k8s-nameserver, ts_kube
# + ts_package_container go tags). Built on the ringtail nix-container-builder.
# Replaces the floating docker.io/tailscale/k8s-nameserver:stable tag, which is
# also the regression vector behind the v1.96.5 MagicDNS-in-containers bug.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.98.5";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/tailscale.git";
    rev = "v${version}";
    hash = "sha256-JaVCmMdZMaP/8RaNRmYpQOj+y/NfHuXdqp8qyWNYEqM=";
  };

  # v1.98.5 go.mod floor is go >= 1.26.3; nixpkgs default Go (1.25.x) fails with
  # GOTOOLCHAIN=local, so pin go_1_26 explicitly (buildGoModule toolchain floor).
  nameserver = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "tailscale-k8s-nameserver";
    vendorHash = "sha256-mbxLXR2TBgiwyVGfLmMR5xWk+0f66mPDas95Wla70Lk=";

    subPackages = [ "cmd/k8s-nameserver" ];

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
      description = "Tailscale nameserver for Kubernetes (MagicDNS in-cluster)";
      homepage = "https://tailscale.com";
      license = licenses.bsd3;
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/tailscale-k8s-nameserver";
  tag = "v${version}";

  contents = [
    nameserver
    pkgs.cacert
  ];

  # buildGoModule names the binary after the package dir (k8s-nameserver);
  # upstream's image expects /usr/local/bin/k8s-nameserver.
  extraCommands = ''
    mkdir -p usr/local/bin
    ln -s /bin/k8s-nameserver usr/local/bin/k8s-nameserver
  '';

  config = {
    Entrypoint = [ "/usr/local/bin/k8s-nameserver" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
