{ lib, config, ... }:

# Flake invariants: incident lessons encoded as evaluation-time guards, so a
# reintroduced config shape fails the flake-check build before it can reach the
# host. Message format per entry:
#   <what is forbidden or required> — <why/lesson>. Incident <link>. To lift: <deliberate action>.

let
  # launchd runs argv0 before /nix is mounted at login; a store-path argv0 dies
  # EX_CONFIG and launchd never retries. Jobs either enter through the
  # mcquack.nix-wait wrappers (user: ~/.local/bin/mcquack.nix-wait, system:
  # /usr/local/libexec/mcquack.nix-wait) or keep their non-store binaries.
  inStore = p: lib.hasInfix "/nix/store" p;
  # launchd takes argv0 from Program when it is set, else ProgramArguments[0].
  argv0Of = cfg:
    if cfg.Program != null then
      cfg.Program
    else if (cfg.ProgramArguments or []) == [] then
      null
    else
      builtins.head cfg.ProgramArguments;
  guard = name: cfg:
    let
      argv0 = argv0Of cfg;
    in
    lib.optional (argv0 != null && inStore argv0) {
      assertion = false;
      message = "indri: launchd ${name} argv0 points into /nix/store — launchd starts the job before /nix is mounted, the process dies EX_CONFIG and is never respawned. Incidents https://forge.ops.eblu.me/eblume/blumeops/issues/1225, https://forge.ops.eblu.me/eblume/blumeops/issues/1363. To lift: run the job behind the mcquack.nix-wait wrappers in the same PR, or move the binary to a non-store location.";
    };
  guardNamed = domain: name: agent: guard (domain + " " + name) agent.serviceConfig;
  userAgents = config.launchd.user.agents;
  daemons = config.launchd.daemons;
  exitTimeOutWarning = name: cfg:
    lib.optional (cfg.ExitTimeOut != null && cfg.ExitTimeOut > 60 && cfg.AbandonProcessGroup != true)
      "indri: launchd user agent ${name} sets ExitTimeOut ${lib.toString cfg.ExitTimeOut} s without AbandonProcessGroup — launchd clamps ExitTimeOut to 60 s in the per-user gui domain, and without AbandonProcessGroup a stop kills the job's process group, taking a detached darwin-rebuild mid-activation. Incidents https://forge.ops.eblu.me/eblume/blumeops/issues/1266, https://forge.ops.eblu.me/eblume/blumeops/issues/1269. To lift: set AbandonProcessGroup = true in the same PR, or silence the warning in this file if the long timeout is deliberate.";
  # Secrets lockstep with secrets.json (eblume/blumeops#1524): every path the
  # nix config reads on host must be declared in the manifest, and vice
  # versa. The main runner's identity files are the first reference sites
  # (the darwin/indri generation checks slot + config render, eblume/blumeops#1528);
  # the indri-build runner's identity files join when the generation takes
  # over its config render (eblume/blumeops#1627). The heph hub's
  # authorized-sub file is a third reference site for the store flip
  # (eblume/blumeops#1655).
  secrets = builtins.fromJSON (builtins.readFile ./secrets.json);
  declared = builtins.map (s: s.path) secrets.secrets;
  referenced = [
    "/Users/erichblume/forgejo-runner/identity/uuid"
    "/Users/erichblume/forgejo-runner/identity/token"
    "/Users/erichblume/forgejo-runner/identity/mise-github-token"
    "/usr/local/etc/forgejo-runner-build/identity/uuid"
    "/usr/local/etc/forgejo-runner-build/identity/token"
    "/usr/local/etc/forgejo-runner-build/identity/mise-github-token"
    "/Users/erichblume/.config/heph-hub/authorized-sub"
    "/Users/erichblume/.config/zot/oidc-credentials.json"
    "/Users/erichblume/.config/metrics-keys/forgejo-api-key"
    "/Users/erichblume/.config/metrics-keys/jellyfin-api-key"
  ];
in
{
  # argv0 across every user agent and system daemon.
  assertions = lib.flatten (lib.mapAttrsToList (guardNamed "user agent") userAgents)
    ++ lib.flatten (lib.mapAttrsToList (guardNamed "daemon") daemons)
    # Secrets lockstep with secrets.json, same shape as ringtail's guard (see
    # the `referenced` binding above).
    ++ [
      {
        assertion = lib.all (p: lib.elem p declared) referenced;
        message = let
          missing = lib.filter (p: ! lib.elem p declared) referenced;
        in "indri: the nix config references secret ${lib.concatMapStringsSep ", " (p: "<${p}>") missing} that is not declared in darwin/indri/secrets.json — the apply path would have no declared owner for it. eblume/blumeops#1524. To lift: add the entry to the manifest in the same PR, or remove this entry in the same PR if the reference is deliberate.";
      }
      {
        assertion = lib.all (p: lib.elem p referenced) declared;
        message = let
          dead = lib.filter (p: ! lib.elem p referenced) declared;
        in "indri: secrets.json declares ${lib.concatMapStringsSep ", " (p: "<${p}>") dead} that no part of the nix config references — a dead declaration is a typo in the manifest, or a copy task the manifest was supposed to retire. eblume/blumeops#1524. To lift: reference the path from the config, or remove the entry from the manifest in the same PR.";
      }
    ];
  # gui domain only: launchd clamps ExitTimeOut to 60 s per user agent; the
  # system daemons honor it, so only user agents are warned.
  warnings = lib.flatten (lib.mapAttrsToList (n: a: exitTimeOutWarning n a.serviceConfig) userAgents);
}
