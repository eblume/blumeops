Service review: bumped `blumeops-pg` PostgreSQL operand 18.3 → 18.4
(ghcr.io/cloudnative-pg/postgresql), picking up the May 2026 security release
(11 CVEs incl. CVE-2026-6473 buffer overruns and several SQL-injection fixes);
18.x→18.x needs no dump/restore. Updated ringtail flake.lock (nixpkgs
`d6df3513` → `3cac626e`, nixos-25.11; `nixpkgs-services` pin held) via
`dagger call flake-update`.
