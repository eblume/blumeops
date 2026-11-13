# Red fixture: a fetchzip postFetch whose download rename is a command
# substitution. The rename rule only rewrites a safe name, so the line stays
# literal and the text is unlisted (README Boundaries).
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchzip {
  url = "https://example.com/a.zip";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  postFetch = ''
    renamed="$TMPDIR/x`id`y"
    mv "$downloadedFile" "$renamed"
    unpackFile "$renamed"
  '';
})
