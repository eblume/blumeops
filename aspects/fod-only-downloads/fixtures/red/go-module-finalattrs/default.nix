# Red: the `(finalAttrs: { ... })` lambda form is the current nixpkgs idiom;
# the vendor FOD check must see through it.
pkgs.buildGoModule (finalAttrs: {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  preBuild = ''
    make gen
  '';
})
