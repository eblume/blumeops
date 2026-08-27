Daily service review: borgmatic role pin drifted to 2.1.4 (indri's actually
installed version) while mise.toml and service-versions.yaml claimed 2.1.7.
Bumped ansible/roles/borgmatic/defaults/main.yml to 2.1.7, the upstream
latest. Changelog 2.1.5-2.1.7 reviewed — the only breaking change (Cronhub
monitoring hook removal) is not used by indri's config.
