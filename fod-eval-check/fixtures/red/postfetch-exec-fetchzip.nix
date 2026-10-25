# Red fixture (open item): an executing postFetch on a fetchzip FOD.
# The postFetch text is per-package source content, so the eval check does not
# yet pin it (README Boundaries). This fixture pins the mechanism: the check
# must reject it once the per-package postFetch surface is closed.
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchzip {
  url = "https://example.com/a.zip";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  postFetch = o.postFetch + "bash $downloadedFile\n";
})
