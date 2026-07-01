Added `retries: 3` / `retry_wait: 300` to the [[borgmatic]] config so a transient
failure on a single repository — e.g. a broken SSH pipe partway through a large
offsite upload to BorgBase — is retried (resuming from borg's checkpoint) instead
of losing that night's backup. Surfaced when PR #407 repointed the forgejo source
from the empty `/opt/homebrew/var/forgejo` husk to the real ~8.8 GB tree: the
first offsite run under the new config had ~6.7 GB of new deduplicated data to
push, the pipe broke mid-transfer (borg exit 87), and the night's offsite backup
failed with no retry. The dump hooks (`before: configuration`) are not re-run on
retry.
