The dispatch token belongs in the `blumeops` vault: 1Password Connect (and
so external-secrets) is scoped to that vault alone, while `blumeops-ci` is
for CI job-time `op read`. Also: `/healthz` now reports
`armed | armed-no-token | disarmed`, so a missing token is visible instead
of masquerading as "disabled".
