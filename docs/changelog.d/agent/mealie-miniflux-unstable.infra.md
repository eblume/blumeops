Bump mealie v3.16.0 -> v3.20.1 (bump-with-review to what nixos-unstable
currently carries; no DB/schema breaking changes, SQLite continues to
auto-migrate forward via init_db) and miniflux 2.3.1 -> 2.3.2 (converted to
the same nixos-unstable self-pin as mealie/navidrome, since stable
nixos-25.11 is EOL; 2.3.2 is a security patch preventing username
enumeration via login timing).
