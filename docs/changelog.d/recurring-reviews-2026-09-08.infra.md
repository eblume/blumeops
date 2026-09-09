Daily service review: cv (ansible, last reviewed 2026-04-29). Deployed
v1.0.3 is still the newest published package: v1.0.4 is parked on
[eblume/horkos#17](https://forge.eblu.me/eblume/horkos/issues/17) step 4, the
cv release-path rewrite, and the source repo's build deps were already
refreshed by [eblume/cv#3](https://forge.eblu.me/eblume/cv/pulls/3) (alpine
3.23, Dagger v0.21.9, WeasyPrint pinned 69.0, merged 2026-09-05). Per the
reviewer on [eblume/blumeops#941](https://forge.eblu.me/eblume/blumeops/issues/941)
the version is left as-is this cycle since the deploy story is changing
soon; the revamp is filed as its own issue. The bot token still lacks the
`read:package` scope, so published package versions cannot be enumerated
from the pod — noted in the revamp issue. Stamped last-reviewed in
service-versions.yaml; no version bump.
