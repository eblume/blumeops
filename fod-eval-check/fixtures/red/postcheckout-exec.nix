# Red fixture: an executing postCheckout on a fetchgit FOD.
# The canonical fetchgit template's postCheckout (forwarded as
# NIX_PREFETCH_GIT_CHECKOUT_HOOK) is empty; this instance's postCheckout runs
# `bash evil.sh` inside the fixed-output build after the repo checkout and
# before the hash is fixed. postCheckout must be compared strictly to the
# template (or pinned non-empty), or the check accepts this FOD.
let
  pkgs = import <nixpkgs> { };
in
pkgs.fetchgit {
  url = "https://example.com/repo.git";
  rev = "61f98e459f7f9d5fad6a79992f0dd310de359e10";
  hash = pkgs.lib.fakeHash;
  postCheckout = "bash evil.sh";
}
