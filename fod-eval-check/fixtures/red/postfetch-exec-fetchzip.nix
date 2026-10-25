# Red fixture: an executing postFetch on a fetchzip FOD. The exact-text
# allow-list rejects it (README Boundaries).
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchzip {
  url = "https://example.com/a.zip";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  postFetch = o.postFetch + "bash $downloadedFile\n";
})
