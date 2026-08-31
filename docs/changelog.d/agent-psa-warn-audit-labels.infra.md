Add Pod Security Admission (PSA) `warn` + `audit` labels at each app
namespace's target level (`restricted` for most, `baseline` for
hostPath-using ollama/talos), with no `enforce` yet — step 1 of the rollout
in heph `01KVQX81703HDE77ED88XDPSR2`. Exemptions (alloy, nvidia-device-plugin,
prowler) and deferrals (cnpg-system, databases, tailscale) are documented in
`docs/reference/operations/security.md`.
