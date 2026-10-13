{ lib }:

# Loads forge/runners.json for the nix consumers (darwin/indri,
# nixos/ringtail) and refuses, at evaluation time, any value that would
# not survive the trip into its destination: names and units become
# Prometheus label values and systemd instance names, labels become runner
# registration arguments, capacity becomes a metric value and a config
# integer. Returns the validated list of runner entries.

let
  file = builtins.fromJSON (builtins.readFile ./runners.json);
  matches = re: v: builtins.isString v && builtins.match re v != null;
  ident = "[A-Za-z0-9._-]+";
  fail = r: field: rule:
    throw "forge/runners.json: runner ${builtins.toJSON (r.name or null)} field `${field}` = ${builtins.toJSON (r.${field} or null)} ${rule}";
  check = r:
    if !(matches ident (r.name or null)) then fail r "name" "must match ${ident}"
    else if !(matches ident (r.host or null)) then fail r "host" "must match ${ident}"
    else if !(matches ident (r.unit or null)) then fail r "unit" "must match ${ident}"
    else if !(builtins.isList (r.labels or null) && r.labels != [ ] && lib.all (matches "[A-Za-z0-9._:-]+") r.labels)
    then fail r "labels" "must be a non-empty list of strings matching [A-Za-z0-9._:-]+"
    else if !(builtins.isInt (r.capacity or null) && r.capacity > 0) then fail r "capacity" "must be a positive integer"
    else if !(builtins.isBool (r.privileged or null)) then fail r "privileged" "must be a boolean"
    else r;
  runners = map check file.runners;
  names = map (r: r.name) runners;
in
assert lib.assertMsg (lib.length (lib.unique names) == lib.length names)
  "forge/runners.json: runner names must be unique (got ${builtins.toJSON names})";
runners
