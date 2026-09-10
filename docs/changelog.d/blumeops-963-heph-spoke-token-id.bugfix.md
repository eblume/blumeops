The ringtail agent heph spoke's token store now addresses its 1Password item by
id and refuses to create on any save error other than a definite not-found,
stopping the duplicate-item cascade (eblume/blumeops#963). The same-class
get-then-create cascades in `agent-authkey-sync` and `warrant-bot-provision`
get the same not-found gating and the loud abort on duplicates.
