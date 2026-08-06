`warrant-bot-drift` and `agent-repo-access` read a collaborator's permission
level from `/collaborators/{who}/permission` instead of from the collaborator
list, whose entries are plain users and never carried a permissions field.
Warrant Bot Drift could not pass at all — every real grant read as "not
readable" (run 724); `agent-repo-access` saw every existing grant as `read`,
so `--check` never reported in sync and an over-privileged grant would have
read as under-privileged.
