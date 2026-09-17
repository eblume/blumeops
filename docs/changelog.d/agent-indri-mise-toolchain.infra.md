The indri play's imperative mise toolchain provisioning (go baseline,
`go.set_goroot`, the forgejo runner's host CI tools) is now declarative:
the indri nix-darwin flake owns the global mise config, which activation
symlinks into `~/.config/mise/config.toml`. The play keeps only the
Homebrew mise install and version floor.
