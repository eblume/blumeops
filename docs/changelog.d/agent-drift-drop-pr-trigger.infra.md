Trade Warrant Bot Drift's `pull_request` trigger for a `push` on `main` over
the same paths. The job reads collaborator permissions and branch protections,
which needs `FORGE_ADMIN_TOKEN`; fork PRs receive no secrets and every agent PR
is a fork PR, so as a PR check it could only reach `--skip-if-no-token` — which
exits 0 and renders as a green tick. That false pass is how PR #506 merged a
check that could never have passed. The post-merge `push` run is the first one
with a real token, and the weekly schedule remains the standing check; neither
can pass by abstaining.
