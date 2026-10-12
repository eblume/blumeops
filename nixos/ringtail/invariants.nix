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
  ];
}
