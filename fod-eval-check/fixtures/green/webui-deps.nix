let
  pkgs = import <nixpkgs> { };
in
import ../../../containers/authentik/webui-deps.nix { inherit pkgs; }

