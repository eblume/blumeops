Upgraded kube-state-metrics v2.18.0 → v2.19.1 (service review) — nix container
rebuild from the forge mirror, picking up Go-toolchain and golang.org/x CVE
fixes plus the pprof auth-filter hardening from v2.19.0. Added a
`RuntimeDefault` seccomp profile to its deployment, remediating one of the
Prowler K8s CIS findings. Compliance triage of the weekly Prowler report (18
unmuted, net-zero week-over-week) reworked the mutelist for the k3s finding
profile: alloy node agents, the nvidia device plugin, local-path-provisioner,
the k3s cloud-controller, and kube-apiserver node-proxy access are now muted as
upstream-managed system/node-agent privileges. Remaining app-pod seccomp
findings (authentik, frigate-notify) are tracked for RuntimeDefault remediation.
