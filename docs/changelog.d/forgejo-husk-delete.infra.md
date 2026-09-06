- Deleted the dead Homebrew-era Forgejo tree (`/opt/homebrew/var/forgejo`, 6.4 GB,
  frozen since 2026-04-06) from indri — the last item of #798. Pre-delete checks:
  the tree shared no inodes, symlinks, or open files with the live `~/forgejo`,
  no LaunchAgent or borgmatic config referenced it, and borgmatic retention is
  count-based so nothing depends on the path existing. It did hold one thing
  that existed nowhere else: the `eblume/hermes` repo (the task tracker
  hephaestus replaced; unrelated to the 2020 GitHub repo of the same name) with
  two tagged releases and their four assets. It was a three-day template
  scaffold with a hello-world route, so after review it was deliberately
  discarded rather than archived. Also fixed: the husk's mirror `config` files still embedded a
  GitHub PAT in their remote URLs, so the delete removes a plaintext credential
  copy; and the stale `--repo eblume/hermes` example in AGENTS.md now names
  `eblume/talos`.
