Fix `horkos-forge-provision --rotate` aborting on its own new-PAT check: prove ownership via the bot's token list and usability via push on blumeops, not `GET /user` (which needs `read:user`).
