# Red: an inherited vendor-FOD attr reached through a dotted reference
# (cfg.script) is not gradable - the string it holds may be shell.
let
  cfg = {
    script = "go generate ./...";
  };
in
pkgs.buildGoModule {
  pname = "evil-module";
  vendorHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  preBuild = cfg.script;
}
