import dagger
from dagger import dag, function, object_type

NIX_IMAGE = "nixos/nix:2.33.3"


@object_type
class BlumeopsCi:
    @function
    def build(self, src: dagger.Directory, container_name: str) -> dagger.Container:
        """Build a container from containers/<name>/Dockerfile."""
        context = src.directory(f"containers/{container_name}")
        return context.docker_build()

    @function
    async def publish(
        self,
        src: dagger.Directory,
        container_name: str,
        version: str,
        registry: str = "registry.ops.eblu.me",
    ) -> str:
        """Build and push to registry. Returns the image ref."""
        ctr = self.build(src, container_name)
        ref = f"{registry}/blumeops/{container_name}:{version}"
        return await ctr.publish(ref)

    @function
    async def build_docs(self, src: dagger.Directory, version: str) -> dagger.File:
        """Build Quartz docs site. Returns docs tarball."""
        return await (
            dag.container()
            .from_("node:22-slim")
            .with_exec(["apt-get", "update", "-qq"])
            .with_exec(["apt-get", "install", "-y", "-qq", "git"])
            .with_directory("/workspace", src)
            .with_workdir("/workspace")
            .with_exec(
                [
                    "git",
                    "clone",
                    "--depth=1",
                    "https://github.com/jackyzha0/quartz.git",
                    "/tmp/quartz",
                ]
            )
            .with_exec(
                [
                    "sh",
                    "-c",
                    "cp -r /tmp/quartz/quartz /tmp/quartz/package*.json "
                    "/tmp/quartz/tsconfig.json .",
                ]
            )
            .with_exec(["npm", "ci"])
            .with_exec(["cp", "docs/quartz.config.ts", "."])
            .with_exec(["cp", "docs/quartz.layout.ts", "."])
            .with_exec(["cp", "CHANGELOG.md", "docs/"])
            .with_exec(["npx", "quartz", "build", "-d", "docs"])
            .with_exec(
                [
                    "tar",
                    "-czf",
                    f"/docs-{version}.tar.gz",
                    "-C",
                    "public",
                    ".",
                ]
            )
            .file(f"/docs-{version}.tar.gz")
        )

    @function
    async def build_nix(
        self, src: dagger.Directory, container_name: str
    ) -> dagger.File:
        """Build a nix container from containers/<name>/default.nix.

        Returns the docker-archive tarball that can be loaded with
        `docker load` or pushed with `skopeo copy`.
        """
        nix_file = f"containers/{container_name}/default.nix"
        # Resolve nixpkgs store path from flake registry, then build.
        # Uses nix-instantiate to parse JSON (avoids needing jq).
        resolve_and_build = (
            "set -e; "
            "nix --extra-experimental-features 'nix-command flakes' "
            "flake metadata nixpkgs --json > /tmp/nixpkgs.json; "
            "NIXPKGS_PATH=$(nix-instantiate --eval -E "
            '"(builtins.fromJSON (builtins.readFile /tmp/nixpkgs.json)).path" '
            "| tr -d '\"'); "
            'export NIX_PATH="nixpkgs=$NIXPKGS_PATH"; '
            'echo "NIX_PATH=$NIX_PATH"; '
            'nix-build "$1" -o /result'
        )
        return await (
            dag.container()
            .from_(NIX_IMAGE)
            .with_directory("/workspace", src)
            .with_workdir("/workspace")
            .with_exec(["sh", "-c", resolve_and_build, "_", nix_file])
            .file("/result")
        )

    @function
    async def nix_version(self, package: str) -> str:
        """Extract the version of a nixpkgs package. Returns version string."""
        return await (
            dag.container()
            .from_(NIX_IMAGE)
            .with_exec(
                [
                    "nix",
                    "--extra-experimental-features",
                    "nix-command flakes",
                    "eval",
                    "--raw",
                    f"nixpkgs#{package}.version",
                ]
            )
            .stdout()
        )

    @function
    async def flake_lock(
        self, src: dagger.Directory, flake_path: str = "nixos/ringtail"
    ) -> dagger.File:
        """Resolve flake inputs and return updated flake.lock."""
        return await (
            dag.container()
            .from_(NIX_IMAGE)
            .with_directory("/workspace", src)
            .with_workdir(f"/workspace/{flake_path}")
            .with_exec(
                [
                    "nix",
                    "--extra-experimental-features",
                    "nix-command flakes",
                    "flake",
                    "lock",
                    "--accept-flake-config",
                ]
            )
            .file(f"/workspace/{flake_path}/flake.lock")
        )
