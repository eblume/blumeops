Remove the duplicate Homepage tiles for Mealie, Paperless, Immich, and
TeslaMate. Homepage runs on ringtail and autodiscovers ringtail Ingresses via
`gethomepage.dev/*` annotations; once these services migrated to ringtail they
were discovered automatically, making their leftover static `services.yaml`
entries (needed only while they lived on minikube) redundant.
