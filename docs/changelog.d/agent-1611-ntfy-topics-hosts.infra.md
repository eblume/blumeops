The ringtail and indri apply watchers read their ntfy topic from the ntfy/topics.json declaration at nix eval time (ntfy/topics.nix); a topic change ships on the next apply of either host.
Both flake checks (ringtail, indri) now also run on ntfy/** and forge/runners.* changes, so edits to the shared flake inputs get a build check on each host before merge.
