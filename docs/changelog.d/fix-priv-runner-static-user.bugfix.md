Ringtail's priv runner now runs as the static system user `horkos-runner` instead of a DynamicUser, so the ringtail-rebuild polkit rule matches again and no longer also admits the nix builder.
