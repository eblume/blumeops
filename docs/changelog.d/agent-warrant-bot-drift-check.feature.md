`mise run warrant-bot-drift` and a weekly **Warrant Bot Drift** workflow assert
that warrant-bot still holds exactly write on `eblume/blumeops`, is a
collaborator nowhere else, is not a site admin, and is not on `main`'s
push/merge whitelist. All four live in the forge rather than in this repo, so a
change made in the UI leaves no diff for review to catch. Read-only, and an
unreadable check reports UNKNOWN and fails rather than passing quietly.
