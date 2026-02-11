import dagger
from dagger import function, object_type


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
