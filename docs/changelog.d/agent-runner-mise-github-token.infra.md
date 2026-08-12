The indri runner now injects `MISE_GITHUB_TOKEN` into every job's environment
via `runner.envs`, sourced at provision time from the `forge-ci-github-pat`
1Password field. Forgejo sets `GITHUB_TOKEN` in every job to the *forge* job
token, and mise honours that name for `api.github.com` — so any GitHub-backed
tool resolution took a 401. `MISE_GITHUB_TOKEN` outranks it in mise's lookup
order (first non-empty of `MISE_GITHUB_TOKEN`, `GITHUB_API_TOKEN`,
`GITHUB_TOKEN` wins), fixing the class for every repo the runner builds with
no workflow changes.

The token is the same zero-permission public-read PAT the mirror sync uses —
readable by every job on the runner, which is exactly why it must never grow a
scope. Takes effect at the next `provision-indri`; after that,
hephaestus.nvim's per-step `GITHUB_TOKEN: ""` workaround can come out
(blumeops' own Lint keeps its blank deliberately — that job is
credential-free by design and no longer touches the GitHub API at all).

heph: 01KZKP8893WM8DQT5N97QF6PBD (design), 01KZP94PSDXAMV3GNN2WE51HGA
(credential decision).
