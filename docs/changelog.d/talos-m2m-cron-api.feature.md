talos now trusts the shared `agents-m2m` machine identity as a second bearer
issuer (companion talos#22), so scripts, services, and non-talos agent
sessions can drive the talos API — e.g. create scheduled cron jobs (talos#21)
— without a browser login. Warrant + human approval still gates every
privileged action. Credential: `agents-m2m-app-password` (blumeops vault); no
wrapper task, just the API.
