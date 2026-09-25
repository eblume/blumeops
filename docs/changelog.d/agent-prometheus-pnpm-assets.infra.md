Prometheus's web UI moved from npm to pnpm upstream at v3.13.0, which broke
the Nix-built v3.14.0 image build (no package-lock.json). The container
derivation now fetches the pnpm workspace with fetchPnpmDeps/pnpmConfigHook
(pnpm 10, nodejs 22) and builds the assets via the repo's own build_ui.sh, so
the v3.14.0 image builds again.
