# Red: a fetcher FOD hook (postFetch) reached through a dotted reference is
# not gradable - the string it holds may be shell.
let
  cfg = {
    s = "sh $out";
  };
in
pkgs.fetchurl {
  url = "https://example.com/a";
  sha256 = "sha256-A";
  postFetch = cfg.s;
}
