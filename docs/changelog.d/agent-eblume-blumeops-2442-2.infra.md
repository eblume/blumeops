Ringtail's nix-container-builder runners each run as their own static user, so their workspaces are no longer mounted noexec; the `bash` wrappers in the flake-update workflow are removed.
