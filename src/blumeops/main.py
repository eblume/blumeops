import dagger
from dagger import dag, function, object_type

NIX_IMAGE = "nixos/nix:2.34.4"


@object_type
class Blumeops:
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
                    # Pin to last v4 release. v5.0.0 restructured config
                    # layout (.quartz/plugins, ../quartz imports) and breaks
                    # our quartz.config.ts/quartz.layout.ts. See changelog.
                    "--branch=v4.5.2",
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
    async def validate_workflows(
        self,
        src: dagger.Directory,
        runner_version: str = "12.7.0",
    ) -> str:
        """Validate Forgejo Actions workflow files against runner schema.

        Runs forgejo-runner validate (available v9.0+) against all workflow
        files in .forgejo/workflows/. Returns validation output. Fails if
        any workflow has schema errors.
        """
        return await (
            dag.container()
            .from_(f"code.forgejo.org/forgejo/runner:{runner_version}")
            .with_directory("/workspace", src)
            .with_workdir("/workspace")
            .with_exec(["forgejo-runner", "validate", "--directory", "."])
            .stdout()
        )

    @function
    async def flake_update(
        self,
        src: dagger.Directory,
        flake_path: str = "nixos/ringtail",
        skip_inputs: str = "nixpkgs-services",
    ) -> dagger.File:
        """Update rolling flake inputs to latest and return updated flake.lock.

        Dynamically discovers all flake inputs, filters out skip_inputs
        (comma-separated), and passes the rest as positional args to
        `nix flake update`. This avoids hardcoding input names.

        Args:
            src: Source directory containing the flake.
            flake_path: Path to the flake within src.
            skip_inputs: Comma-separated input names to exclude from update.
        """
        # nix has no --exclude flag; instead we enumerate inputs via
        # `nix flake metadata --json` and pass the ones we want as
        # positional args.
        update_script = (
            "set -e; "
            # Double quotes: single quotes would keep $SKIP_INPUTS literal and
            # silently disable the skip filter (letting `nix flake update`
            # bump the deliberately-pinned nixpkgs-services input).
            'SKIP="$SKIP_INPUTS"; '
            # Land the metadata in a real file: nix-instantiate cannot
            # readFile a pipe (/dev/stdin canonicalizes to
            # /proc/<pid>/fd/pipe:[...] and readFile fails), which made
            # discovery silently empty for as long as this pipeline existed.
            # No stderr suppression — metadata failures should be visible.
            "nix --extra-experimental-features 'nix-command flakes' "
            "flake metadata --json > /tmp/flake-meta.json; "
            "ALL=$(nix-instantiate --eval -E "
            '"builtins.concatStringsSep \\" \\" '
            "(builtins.attrNames "
            "(builtins.fromJSON (builtins.readFile /tmp/flake-meta.json))"
            '.locks.nodes.root.inputs)" '
            "| tr -d '\"'); "
            "INPUTS=''; "
            "for i in $ALL; do "
            '  case ",$SKIP," in *",$i,"*) continue ;; esac; '
            '  INPUTS="$INPUTS $i"; '
            "done; "
            'echo "Updating inputs:$INPUTS"; '
            'echo "Skipping: $SKIP"; '
            # Empty INPUTS would make `nix flake update` update *all* inputs,
            # including the ones we meant to skip — fail loudly instead.
            '[ -n "$INPUTS" ] || { echo "no inputs discovered; refusing bare flake update" >&2; exit 1; }; '
            "nix --extra-experimental-features 'nix-command flakes' "
            "flake update $INPUTS --accept-flake-config"
        )
        return await (
            dag.container()
            .from_(NIX_IMAGE)
            .with_directory("/workspace", src)
            .with_workdir(f"/workspace/{flake_path}")
            .with_env_variable("SKIP_INPUTS", skip_inputs)
            .with_exec(["sh", "-c", update_script])
            .file(f"/workspace/{flake_path}/flake.lock")
        )
