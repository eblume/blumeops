Track the two user-facing heph installs in `service-versions.yaml`:
`heph-cli-ringtail` (Erich's desktop spoke, pinned by `hephTag`) and
`heph-cli-gilbert` (installed by hand, the only heph install not under IaC).
Previously only the indri hub and the ringtail agent spoke were tracked, so a
version review could never surface the CLIs Erich actually types at.

`heph-cli-gilbert` starts with null `last-reviewed`/`current-version` — nothing
asserts gilbert's version and the host was unreachable — which floats it to the
top of the review queue, where an untracked install belongs. Documents the
`type` values actually in use (the reference card listed neither `container` nor
`manual`) and when null fields are the right answer.
