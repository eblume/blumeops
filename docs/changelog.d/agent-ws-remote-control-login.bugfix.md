Remote Control refuses `claude setup-token` credentials — with
`CLAUDE_CODE_OAUTH_TOKEN` exported, claude exits at startup ("Long-lived
tokens … are limited to inference-only"), so the v0.16.0 agent-ws pod
crash-looped on its startup probe. v0.17.0 drops the export and returns to
the PVC `claude auth login` credential; its ~7-day expiry is now managed by a
recurring 5-day rotation chore documented in the new
[[rotate-agent-ws-claude-login]] how-to.
