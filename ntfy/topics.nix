{ lib }:

# Loads ntfy/topics.json for the host configs (nixos/ringtail, darwin/indri)
# and validates at eval time the shape they rely on, mirroring
# forge/runners.nix: the name becomes part of the ntfy URL, so a malformed
# entry fails the eval instead of the watcher posting to a nonsense topic.
# Returns the validated list of topic entries.

let
  file = builtins.fromJSON (builtins.readFile ./topics.json);
  matches = re: v: builtins.isString v && builtins.match re v != null;
  # Mirrors ntfy-lint NAME_RE ([A-Za-z0-9._-]+) so a topic that passes
  # the lint cannot fail the host eval on its name.
  ident = "[A-Za-z0-9._-]+";
  fail = t: field: value: rule:
    throw "ntfy/topics.json: topic ${builtins.toJSON (t.name or null)} field `${field}` = ${builtins.toJSON value} ${rule}";
  check = t:
    let priority = t.budget.priority or null; in
    if !(matches ident (t.name or null)) then fail t "name" (t.name or null) "must match ${ident}"
    else if !(builtins.isList (t.producers or null) && lib.all (p: builtins.isString p && p != "") t.producers)
    then fail t "producers" (t.producers or null) "must be a list of non-empty strings"
    else if !(builtins.isInt priority && priority >= 1 && priority <= 5)
    then fail t "budget.priority" priority "must be an integer 1-5"
    else t;
  topics = map check file.topics;
  names = map (t: t.name) topics;
in
assert lib.assertMsg (lib.length (lib.unique names) == lib.length names)
  "ntfy/topics.json: topic names must be unique (got ${builtins.toJSON names})";
topics
