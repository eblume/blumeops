Pin the five local nix images rebuilt with non-root `User 1000` (v8.6.3-f403fce-nix
authentik-redis, v8.1.7-f403fce-nix valkey, v3.20.1-f403fce-nix mealie,
v2.20.15-f403fce-nix paperless, v3.0.0-f403fce-nix teslamate) and restore the PSA
restricted fields (runAsNonRoot, allowPrivilegeEscalation:false, capabilities drop
ALL; fsGroup 1000 on immich-valkey and mealie) on those five workloads per the
non-root decision table in docs/reference/operations/security.md.
