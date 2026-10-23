# Red fixture: the classic `curl | sh` FOD — the downloaded script executes
# inside the FOD. curl may only write to a file; nothing may pipe to a shell.
{ pkgs ? import <nixpkgs> { } }:

pkgs.runCommand "installs-script" {
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
} ''
  curl -s https://example.com/install.sh | sh
''
