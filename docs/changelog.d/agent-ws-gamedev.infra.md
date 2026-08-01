`gamedev` joins the agent workspace pool, with the native libraries it actually
needs to build.

The repo was already granted (`access: write`) but held at `pool: none`, so it
had no checkout in the pod. Flipping it to `canonical` is the one-line half.
The other half is that containerization silently dropped Bevy's Linux native
deps: the retired host launcher exported `PKG_CONFIG_PATH` and `LD_LIBRARY_PATH`
over them, and `containers/agent-ws/` was never given the equivalent. So
`gamedev` would have arrived as a checkout that could not be compiled.

Verified from inside the pod rather than reasoned about, which is what caught
the interesting part. A mise-provided `rust@stable` builds and links an ordinary
crate fine; `mise run check` on gamedev fails in a `-sys` build script. But it
fails on **`wayland-sys`**, not only `alsa-sys` — and the host file's comment
asserted that every windowing library was `dlopen`'d at run time and therefore
needed nothing at build time. That was wrong for this dependency set. Porting
the host's `gameBuildDeps`/`gameLibs` split verbatim would have shipped a fix
that still did not build.

So `PKG_CONFIG_PATH` now carries the dev output of the *whole* `gameLibs` set
rather than a hand-picked subset, with the runtime libs on `LD_LIBRARY_PATH` as
before. A `.pc` file no build script asks for costs nothing; a missing one is a
hard failure, and which crates probe at build time is a property of Bevy's
feature flags that will drift.

Rust itself stays out of the image, and that is now confirmed rather than
assumed: `mise install rust@stable` works in the pod (the `ldLibs` loader shim
was already sized for it), installs to `~/.cargo/bin` on the PVC so it survives
restarts, and `gamedev`'s own `mise.toml` pins `rust = "stable"` — so
`mise run check` provisions its own toolchain.

This lets an agent `cargo check`/`build` the Bevy workspace to verify its work.
It does **not** make the pod able to *run* a windowed Bevy app — no GPU, no
display — so playtesting stays a human job, consistent with the
timberborn-parsimony rule.

Image toolchain version 0.11.0 → 0.12.0.
