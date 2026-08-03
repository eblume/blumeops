`warrant-bot-provision`: generate the bot's login password in-process and
store it beside the PAT in one `blumeops-ci` item (the two-item dance had a
read-after-create failure mode), and surface `op`'s own error text instead of
a bare CalledProcessError.
