# The V5-65 "always trust" declaration (eblume/blumeops#1846) as a pure
# function of the two declared files: the repos policy and the runner
# topology. A repo is eligible iff it is `managed: true` and no runner is
# scoped to `<owner>/<repo>` — only the instance-scoped runner can serve its
# PRs, so a talos fork PR's untrusted push reaches no repo-scoped runner.
# Returns { collaborator, repos (sorted names) }.
#
# Builtins only (no nixpkgs input): the test drives it with a bare `nix eval`,
# and the rule must stay in lockstep with `derive_action_trust_policy` in
# mise-tasks/forge-reconcile via the shared fixture tests/fixtures/action-trust/.
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
