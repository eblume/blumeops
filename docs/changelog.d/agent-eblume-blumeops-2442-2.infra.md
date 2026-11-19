Ringtail's nix-container-builder runners each run as their own static user instead of the shared DynamicUser, and the flake-update workflow calls its scripts directly.
