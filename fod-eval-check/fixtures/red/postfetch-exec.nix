# Red fixture: an executing postFetch on a plain fetchurl FOD.
# The canonical fetchurl template's postFetch is empty; this instance's
# postFetch runs `bash $downloadedFile`, executing the downloaded — not yet
# hash-verified — bytes inside the fixed-output build. postFetch must be
# compared strictly to the template (or pinned non-empty), or the check
# accepts this FOD.
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  postFetch = "bash $downloadedFile";
})
