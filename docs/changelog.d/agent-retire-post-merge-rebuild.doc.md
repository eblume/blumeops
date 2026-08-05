Retire the post-merge container rebuild. Since canonical stopped squash-merging,
a build from the PR branch head stays reachable from `main` after the merge, so
its tag becomes `[main]` on its own. Build once from the final branch head and
put the manifest tag bump in the same PR — no rebuild, no follow-up commit.
