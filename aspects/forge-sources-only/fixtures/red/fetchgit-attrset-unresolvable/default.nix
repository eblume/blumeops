let foo = "bar"; in
builtins.fetchGit {
  type = "github";
  owner = "${foo}";
  repo = "x";
  rev = "0000000000000000000000000000000000000000";
}
