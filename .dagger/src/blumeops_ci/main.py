import dagger
from dagger import dag, function, object_type


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
