{ lib, config, ... }:

# Flake invariants: incident lessons encoded as evaluation-time guards, so a
# reintroduced config shape fails the flake-check build before it can reach the
# host. Message format per entry:
#   <what is forbidden or required> — <why/lesson>. Incident <link>. To lift: <deliberate action>.

let
  # launchd runs argv0 before /nix is mounted at login; a store-path argv0 dies
  # EX_CONFIG and launchd never retries, so every job enters through the
  # mcquack.nix-wait wrappers (user: ~/.local/bin/mcquack.nix-wait, system:
  # /usr/local/libexec/mcquack.nix-wait).
  inStore = p: lib.hasInfix "/nix/store" p;
  argv0Of = cfg: if cfg.ProgramArguments != null then builtins.head cfg.ProgramArguments else cfg.Program;
  guard = name: cfg:
    lib.optional (cfg.Program != null || cfg.ProgramArguments != null)
      {
        assertion = !inStore (argv0Of cfg);
        message = "indri: launchd ${name} argv0 points into /nix/store — launchd starts the job before /nix is mounted, the process dies EX_CONFIG and is never respawned. Incidents https://forge.ops.eblu.me/eblume/blumeops/issues/1225, https://forge.ops.eblu.me/eblume/blumeops/issues/1363. To lift: run the job behind the mcquack.nix-wait wrappers in the same PR and remove this entry.";
      };
  guardNamed = domain: name: agent: guard (domain + " " + name) agent.serviceConfig;
  userAgents = config.launchd.user.agents;
  daemons = config.launchd.daemons;
  exitTimeOutWarning = name: cfg:
    lib.optional (cfg.ExitTimeOut != null && cfg.ExitTimeOut > 60 && cfg.AbandonProcessGroup != true)
      "indri: launchd user agent ${name} sets ExitTimeOut ${lib.toString cfg.ExitTimeOut} s without AbandonProcessGroup — launchd clamps ExitTimeOut to 60 s in the per-user gui domain, and without AbandonProcessGroup a stop kills the job's process group, taking a detached darwin-rebuild mid-activation. Incidents https://forge.ops.eblu.me/eblume/blumeops/issues/1266, https://forge.ops.eblu.me/eblume/blumeops/issues/1269. To lift: set AbandonProcessGroup = true in the same PR, or remove this entry if the long timeout is deliberate.";
in
{
  # argv0 across every user agent and system daemon.
  assertions = lib.flatten (lib.mapAttrsToList (guardNamed "user agent") userAgents)
    ++ lib.flatten (lib.mapAttrsToList (guardNamed "daemon") daemons);
  # gui domain only: launchd clamps ExitTimeOut to 60 s per user agent; the
  # system daemons honor it, so only user agents are warned.
  warnings = lib.flatten (lib.mapAttrsToList (n: a: exitTimeOutWarning n a.serviceConfig) userAgents);
}
