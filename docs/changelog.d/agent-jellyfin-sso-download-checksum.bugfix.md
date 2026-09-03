Give the jellyfin role's SSO-Auth plugin download a pinned sha256 checksum.
The unchecksummed `get_url` re-downloaded the GitHub release zip on every
provision-indri run and reported changed (GitHub release assets do not honor
If-Modified-Since, and the /tmp dest is purged at boot). With the checksum,
the task is ok while the pinned file exists and only re-downloads after a
version bump or a cleared /tmp.
