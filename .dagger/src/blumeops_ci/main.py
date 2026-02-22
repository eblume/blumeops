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
        commit_sha: str,
        registry: str = "registry.ops.eblu.me",
        registry_username: str = "zot-ci",
        registry_password: dagger.Secret | None = None,
    ) -> str:
        """Build and push to registry. Returns the image ref.

        Tag format: {version}-{commit_sha} (e.g. v1.0.0-abc1234)
        """
        ctr = self.build(src, container_name)
        if registry_password is not None:
            ctr = ctr.with_registry_auth(registry, registry_username, registry_password)
        ref = f"{registry}/blumeops/{container_name}:{version}-{commit_sha}"
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

    @function
    async def export_yolov9(
        self,
        model_size: str = "c",
        input_size: int = 640,
    ) -> dagger.File:
        """Export YOLOv9 pretrained weights to ONNX for Frigate NVR.

        Downloads pretrained weights from the WongKinYiu/yolov9 repo and
        exports to ONNX with onnx-simplifier. Use with Frigate's
        `model_type: yolo-generic`.

        Args:
            model_size: Model variant: s (small), c (compact), e (extra-large).
            input_size: Input resolution (width and height). 640 recommended.
        """
        output_file = f"yolov9-{model_size}-{input_size}.onnx"
        weights_url = (
            "https://github.com/WongKinYiu/yolov9/releases/download/v0.1/"
            f"yolov9-{model_size}-converted.pt"
        )
        # Patch torch.load to allow weights_only=False (required for
        # YOLOv9 checkpoints that contain non-tensor objects).
        patch_and_export = (
            "set -e; "
            "cd /yolov9 && "
            "sed -i "
            '"s/ckpt = torch.load(attempt_download(w),'
            " map_location='cpu')/ckpt = torch.load(attempt_download(w),"
            " map_location='cpu', weights_only=False)/g\""
            " models/experimental.py && "
            f"python3 export.py --weights ./weights.pt"
            f" --imgsz {input_size} --simplify --include onnx && "
            f"mv ./weights.onnx /output/{output_file}"
        )
        return await (
            dag.container(platform=dagger.Platform("linux/amd64"))
            .from_("python:3.11-slim")
            .with_exec(["apt-get", "update", "-qq"])
            .with_exec(
                [
                    "apt-get",
                    "install",
                    "-y",
                    "-qq",
                    "git",
                    "libgl1",
                    "libglib2.0-0",
                    "cmake",
                    "build-essential",
                ]
            )
            .with_exec(
                [
                    "git",
                    "clone",
                    "--depth=1",
                    "https://github.com/WongKinYiu/yolov9.git",
                    "/yolov9",
                ]
            )
            .with_exec(
                [
                    "pip",
                    "install",
                    "--quiet",
                    "-r",
                    "/yolov9/requirements.txt",
                    "numpy<2",
                    "onnx>=1.18.0",
                    "onnxruntime",
                    "onnx-simplifier>=0.4.1",
                    "onnxscript",
                ]
            )
            .with_exec(["mkdir", "-p", "/output"])
            .with_file("/yolov9/weights.pt", dag.http(weights_url))
            .with_exec(["sh", "-c", patch_and_export])
            .file(f"/output/{output_file}")
        )

    @function
    async def flake_update(
        self, src: dagger.Directory, flake_path: str = "nixos/ringtail"
    ) -> dagger.File:
        """Update all flake inputs to latest and return updated flake.lock."""
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
                    "update",
                    "--accept-flake-config",
                ]
            )
            .file(f"/workspace/{flake_path}/flake.lock")
        )
