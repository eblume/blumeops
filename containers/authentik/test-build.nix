# Test harness for building authentik components on ringtail
# Uses builtins.getFlake instead of <nixpkgs> (ringtail has flakes, no NIX_PATH)
#
# Usage:
#   nix-build test-build.nix -A python-deps --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A authentik-django --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A client-go --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A client-ts --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A authentik-server --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A webui-deps --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A webui --extra-experimental-features 'nix-command flakes'
#   nix-build test-build.nix -A assembled --extra-experimental-features 'nix-command flakes'
let
  pkgs = (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux;
  sources = import ./sources.nix { inherit pkgs; };

  # Individual components (isolated, no cross-wiring)
  _webui = import ./webui.nix { inherit pkgs sources; };

  # Fully wired assembly (webui → authentik-django → authentik-server)
  _authentik-django-assembled = import ./authentik-django.nix { inherit pkgs sources; webui = _webui; };
  _authentik-server-assembled = import ./authentik-server.nix {
    inherit pkgs sources;
    authentik-django = _authentik-django-assembled;
    webui = _webui;
  };
in
{
  # Individual component builds (for debugging in isolation)
  python-deps = import ./python-deps.nix { inherit pkgs sources; };
  authentik-django = import ./authentik-django.nix { inherit pkgs sources; };
  client-go = import ./client-go.nix { inherit pkgs sources; };
  client-ts = import ./client-ts.nix { inherit pkgs sources; };
  authentik-server = import ./authentik-server.nix { inherit pkgs sources; };
  webui-deps = import ./webui-deps.nix { inherit pkgs sources; };
  webui = _webui;

  # Fully assembled stack — tests that all components wire together
  assembled = pkgs.linkFarm "authentik-assembled-${sources.version}" [
    { name = "authentik-django"; path = _authentik-django-assembled; }
    { name = "authentik-server"; path = _authentik-server-assembled; }
    { name = "webui"; path = _webui; }
  ];
}
