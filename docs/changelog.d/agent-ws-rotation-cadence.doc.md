Correct the agent-ws Claude login rotation cadence from 5 days to 21. The
refresh token's window was measured at **~29 days**, not the ~7 previously
documented — that figure came from mistaking the PVC's creation date for the
login date, when the credential had actually been carried onto the PVC from the
pre-container host login 22 days earlier. The runbook now reads the real
`refreshTokenExpiresAt` off the credential at each rotation instead of trusting
the cadence, and records two things learned doing it live: the code paste-back
echoes nothing over `kubectl exec`, and a login performed *after* expiry needs
the container to cycle before Remote Control comes back.
