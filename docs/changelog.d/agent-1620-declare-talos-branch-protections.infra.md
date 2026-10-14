Declare the live branch protections on `talos:main`, `horkos:main`,
`hephaestus.nvim:main` and `project-template:main` in
`forge/branch-protections.json`, so `forge-reconcile --check` flags drift
instead of silently passing over unmanaged protections. The `talos:main`
rule records the post-#337 contexts (`CI / lint|test|typecheck (pull_request)`);
names and status contexts only, no permission changes.
