Docs review: verified `how-to/authentik/mirror-authentik-build-deps.md`
against forge and repo state. The DRF fork upstream is
`goauthentik/django-rest-framework` (now archived), not
`authentik-community/`, and no forge mirror of it was ever created.
Noted the mirror is live and consumed by `containers/authentik/sources.nix`,
and linked `[[manage-forgejo-mirrors]]`.
