Downgraded the security posture: kept the weekly Prowler K8s CIS hygiene scan
but retired the kingfisher secret scanner entirely (ArgoCD app, manifests,
custom container, prek hook, and the forge spork). TruffleHog remains the prek
secret scanner. Also remediated the outstanding app-pod seccomp Prowler findings
by adding `seccompProfile: RuntimeDefault` to the authentik (server/worker/redis)
and frigate-notify pods rather than muting them.
