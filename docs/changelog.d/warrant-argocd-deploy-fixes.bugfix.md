argocd-deploy maiden-run fixes: unset Forgejo's injected `GITHUB_TOKEN`
before `mise x` (it 401s against api.github.com), pre-install `argocd@3.3.12`
as a runner host tool, and list declared Applications when the `app` input
doesn't match (most carry a `-ringtail` suffix).
