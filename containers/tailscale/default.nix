# Nix-built tailscale container for ringtail's tailscale-operator ProxyClass
# Builds v1.98.5 from forge mirror; mirrors upstream Dockerfile contents.
# Built with dockerTools.buildLayeredImage on the ringtail nix-container-builder.
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
  tailscale = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) {
    inherit src version;
    pname = "tailscale";
    vendorHash = "sha256-amKkUPszyhG4N5ZtrB01swBACYq76raSS+SQRneLmwc=";

    subPackages = [
      "cmd/tailscale"
      "cmd/tailscaled"
      "cmd/containerboot"
    ];

    ldflags = [
      "-s"
      "-w"
      "-X tailscale.com/version.longStamp=${version}"
      "-X tailscale.com/version.shortStamp=${version}"
    ];

    doCheck = false;

    meta = with pkgs.lib; {
      description = "The easiest, most secure way to use WireGuard";
      homepage = "https://tailscale.com";
      license = licenses.bsd3;
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/tailscale";
  tag = "v${version}";

  contents = [
    tailscale
    pkgs.cacert
    pkgs.iptables
    pkgs.iproute2
    pkgs.tzdata
    pkgs.busybox
  ];

  # Match upstream Dockerfile: symlink iptables-legacy over iptables.
  # Synology NAS and similar hosts don't support nftables.
  # Also recreate the /tailscale/run.sh compat symlink.
  extraCommands = ''
    rm -f usr/sbin/iptables usr/sbin/ip6tables
    ln -s ${pkgs.iptables}/bin/iptables-legacy usr/sbin/iptables || true
    ln -s ${pkgs.iptables}/bin/ip6tables-legacy usr/sbin/ip6tables || true
    mkdir -p tailscale
    ln -s /bin/containerboot tailscale/run.sh
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Entrypoint = [ "/bin/containerboot" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "PATH=/bin:/usr/bin:/usr/sbin"
    ];
  };
}
