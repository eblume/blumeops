# Green fixture: the allowlisted npm fetch mode — `npm ci --ignore-scripts`
# downloads dependencies without running their scripts, like
# containers/authentik/webui-deps.nix.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "webui-deps";
  src = pkgs.fetchgit {
    url = "https://example.com/web.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  outputHash =
    {
      "x86_64-linux" = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
    }
    .${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "webui-deps: unsupported host platform ${pkgs.stdenvNoCC.hostPlatform.system}");
  outputHashMode = "recursive";

  nativeBuildInputs = with pkgs; [
    nodejs
    cacert
  ];

  buildPhase = ''
    npm ci --cache ./cache --ignore-scripts
    rm -r ./cache node_modules/.package-lock.json
  '';

  # Workspace packages install dependencies into separate node_modules
  # directories — copy all of them
  installPhase = ''
    mkdir $out
    find -type d -name node_modules -prune -print \
      -exec mkdir -p $out/{} \; \
      -exec cp -rT {} $out/{} \;
  '';

  dontCheckForBrokenSymlinks = true;
  dontPatchShebangs = true;
}
