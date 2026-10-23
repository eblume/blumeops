# Nix half of the action-trust rule (python twin: derive_action_trust_policy
# in mise-tasks/forge-reconcile); both pinned by the shared fixture
# tests/fixtures/action-trust/.
# Builtins only (no nixpkgs input) — the test drives it with a bare `nix eval`.
{ reposFile, runnersFile }:
let
  reposJson = builtins.fromJSON (builtins.readFile reposFile);
  runners = (builtins.fromJSON (builtins.readFile runnersFile)).runners or [ ];
  prefix = reposJson.owner + "/";
  scopeOf = r: if r ? scope then r.scope else "";
  eligible =
    builtins.filter
      (e: (if e ? managed then e.managed else false) && builtins.all (r: scopeOf r != prefix + e.name) runners)
      reposJson.repos;
in
{
  collaborator = reposJson.collaborator;
  repos = builtins.sort builtins.lessThan (builtins.map (e: e.name) eligible);
}
