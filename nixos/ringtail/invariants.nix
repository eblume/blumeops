{ lib, config, ... }:

# Flake invariants: incident lessons encoded as evaluation-time guards, so a
# reintroduced config shape fails the flake-check build before it can reach the
# host. Message format per entry:
#   <what is forbidden or required> — <why/lesson>. Incident <link>. To lift: <deliberate action>.

let
  k3s = config.services.k3s;
  # extraFlags is typed `either str (listOf str)` — normalize.
  k3sFlags = if lib.isList k3s.extraFlags then k3s.extraFlags else lib.splitString " " k3s.extraFlags;
  # The nix-container-builder runners' DynamicUser (from the gitea-actions-runner
  # module) runs PR-authored nix builds; trusting that user in the nix daemon
  # would let PR code add unsigned paths to the store and build root's system.
  # The three per-repo instances all run as the module's shared DynamicUser, so
  # checking any one covers all.
  nixBuilderUser = config.systemd.services.gitea-runner-nix_container_builder_blumeops.serviceConfig.User or null;
  nixTrustedUsers = config.nix.settings.trusted-users or [ ];

  # Secrets lockstep with secrets.json (eblume/blumeops#1524): every path the
  # nix config references must be declared in the manifest, and every declared
  # path must be referenced. `referenced` collects the option-driven
  # tokenFiles (k3s.tokenFile, gitea-actions-runner instances) plus the one
  # explicit path agent-heph-spoke.nix reads from its `let`, not from an
  # option — keep this list in sync when adding referrers.
  secrets = builtins.fromJSON (builtins.readFile ./secrets.json);
  declared = builtins.map (s: s.path) secrets.secrets;
  referenced = lib.unique (
    lib.optional (config.services.k3s.tokenFile or null != null) config.services.k3s.tokenFile
    ++ lib.filter (t: t != null) (lib.mapAttrsToList (_: i: i.tokenFile or null) (config.services.gitea-actions-runner.instances or { }))
    ++ [ "/etc/agents/op-token" ]
  );
in
{
  assertions = [
    {
      assertion = nixBuilderUser == null || ! (lib.elem nixBuilderUser nixTrustedUsers);
      message = "ringtail: the nix-container-builder runner user must not be in nix.settings.trusted-users — it runs PR-authored nix builds, and trust lets a PR add unsigned paths to the store and build root's system. eblume/blumeops#1358 amendment 1. To lift: run those builds on a dedicated untrusted user and remove this entry in the same PR.";
    }
    # A shared registration token re-opens the scope #1358 closed: one token
    # means one registration, and the runner advertises its labels to every
    # repo.
    {
      assertion = let
        tokenFiles = lib.filter (t: t != null) (builtins.attrValues (lib.mapAttrs (_: i: i.tokenFile or null) (config.services.gitea-actions-runner.instances or { })));
      in builtins.length (lib.unique tokenFiles) == builtins.length tokenFiles;
      message = "ringtail: gitea-actions-runner instances must not share a tokenFile — a shared registration token is one registration and hands every repo a slot on the runner. eblume/blumeops#1358. To lift: deliberate change and remove this entry in the same PR.";
    }
    # Cluster resources go through ArgoCD, not through k3s' built-in manifest
    # machinery: k3s symlinks them into /var/lib/rancher/k3s/server/manifests
    # and switch-to-configuration does not prune them, so a deleted manifest
    # keeps its resources alive and undeclared resources can appear at boot.
    {
      assertion = ! k3s.enable || k3s.manifests == { };
      message = "ringtail: services.k3s.manifests must stay empty — cluster resources are applied via ArgoCD only, because k3s manifest symlinks outlive deletion. Incident https://forge.ops.eblu.me/eblume/blumeops/issues/1408. To lift: move the resource to ArgoCD in the same PR and remove this entry.";
    }
    {
      assertion = ! k3s.enable || k3s.autoDeployCharts == { };
      message = "ringtail: services.k3s.autoDeployCharts must stay empty — auto-deployed charts bypass the ArgoCD ownership boundary and their HelmChart resources are likewise not pruned. Incident https://forge.ops.eblu.me/eblume/blumeops/issues/1408. To lift: deploy the chart through ArgoCD in the same PR and remove this entry.";
    }
    # A world-readable admin kubeconfig hands cluster-admin to the unprivileged
    # `agent` user and, via the argocd-* secrets, a deploy path — bypassing the
    # vault gate that is supposed to keep agents author-only.
    {
      assertion = ! k3s.enable || lib.elem "--write-kubeconfig-mode=600" k3sFlags;
      message = "ringtail: k3s must keep writing its kubeconfig mode 600 (--write-kubeconfig-mode=600 in services.k3s.extraFlags) — a world-readable admin kubeconfig gives the unprivileged `agent` user cluster-admin. To lift: change the agent authorization model deliberately in the same PR and remove this entry.";
    }
    # A switch restarts the already-running unit, so the first deploy looks
    # fine; the trap is the first reboot, when nothing wants the spoke and
    # the pod's heph socket goes silently dead.
    {
      assertion = lib.elem "multi-user.target" (config.systemd.services."agent-heph-spoke".wantedBy or []);
      message = "ringtail: agent-heph-spoke must be wanted by multi-user.target — a nixos switch restarts the already-running unit, so the first deploy looks fine, but after the first reboot nothing starts the spoke and the pod's heph socket goes silently dead. eblume/blumeops#1624. To lift: give the spoke a different boot trigger and remove this entry in the same PR.";
    }
    # Same lesson at user scope: without the boot trigger, the first reboot
    # kills Erich's desktop heph CLI silently.
    {
      assertion = lib.elem "default.target" (config.systemd.user.services."eblume-heph-spoke".wantedBy or []);
      message = "ringtail: eblume-heph-spoke (user scope) must be wanted by default.target — without it nothing starts the spoke after a reboot and the desktop heph CLI goes silently dead. eblume/blumeops#1541. To lift: give the spoke a different boot trigger and remove this entry in the same PR.";
    }
    # Secrets lockstep, direction 1: the nix config references only declared
    # secret paths, so the apply path always has a declared owner for the file.
    {
      assertion = lib.all (p: lib.elem p declared) referenced;
      message = let
        missing = lib.filter (p: ! lib.elem p declared) referenced;
      in "ringtail: the nix config references secret ${lib.concatMapStringsSep ", " (p: "<${p}>") missing} that is not declared in nixos/ringtail/secrets.json — the apply path would have no declared owner for it. eblume/blumeops#1524. To lift: add the entry to the manifest in the same PR, or remove this entry in the same PR if the reference is deliberate.";
    }
    # Secrets lockstep, direction 2: every declared path is referenced, so a
    # dead declaration — a typo, or a copy task the manifest was meant to
    # retire — fails the build instead of lingering.
    {
      assertion = lib.all (p: lib.elem p referenced) declared;
      message = let
        dead = lib.filter (p: ! lib.elem p referenced) declared;
      in "ringtail: secrets.json declares ${lib.concatMapStringsSep ", " (p: "<${p}>") dead} that no part of the nix config references — a dead declaration is a typo in the manifest, or a copy task the manifest was supposed to retire. eblume/blumeops#1524. To lift: reference the path from the config, or remove the entry from the manifest in the same PR.";
    }
  ];
}
