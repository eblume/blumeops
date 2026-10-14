{ lib }:

# Loads ntfy/topics.json for the host configs (nixos/ringtail, darwin/indri)
# and validates at eval time the shape they rely on, mirroring
# forge/runners.nix: names become part of a ntfy URL, budget.priority is
# recorded in the service card, status drives lint. Returns the validated
# list of topic entries.

let
  file = builtins.fromJSON (builtins.readFile ./topics.json);
  matches = re: v: builtins.isString v && builtins.match re v != null;
  ident = "[A-Za-z0-9.-]+";
  fail = t: field: rule:
    throw "ntfy/topics.json: topic ${builtins.toJSON (t.name or null)} field `${field}` = ${builtins.toJSON (t.${field} or null)} ${rule}";
  check = t:
    if !(matches ident (t.name or null)) then fail t "name" "must match ${ident}"
    else if !(builtins.isList (t.producers or null) && lib.all (p: builtins.isString p && p != "") t.producers)
    then fail t "producers" "must be a list of non-empty strings"
    else if !(builtins.isInt (t.budget.priority or null) && t.budget.priority >= 1 && t.budget.priority <= 5)
    then fail t "budget.priority" "must be an integer 1-5"
    else t;
  topics = map check file.topics;
  names = map (t: t.name) topics;
in
assert lib.assertMsg (lib.length (lib.unique names) == lib.length names)
  "ntfy/topics.json: topic names must be unique (got ${builtins.toJSON names})";
topics
