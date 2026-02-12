Simplify Forgejo runner image (Dagger Phase 3): remove Node.js, Docker CLI, buildx, skopeo, gnupg, lsb-release, and xz-utils. Add tzdata and flyctl. All build tools now live inside Dagger containers.
