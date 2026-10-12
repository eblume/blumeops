Raise the `indri-build` runner from 2 to 4 slots: a blumeops PR push starts
6-8 check jobs at once on it, so a quarter of jobs (25%, 291 of 1,170 over 14
days) waited more than 30s for a free slot (eblume/blumeops#1518). The build
runner gets its own `forgejo_runner_build_capacity` variable (indri-runner
stays on `forgejo_runner_capacity: 2`), its colima VM is sized up to 6 CPU /
6 GiB to carry 4 concurrent jobs, and the collector's static
`forgejo_ci_runner_capacity{runner="indri-build"}` line moves to 4 in step.
